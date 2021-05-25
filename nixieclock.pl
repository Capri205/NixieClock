use strict;
use warnings;
use DateTime;
use Glib ('TRUE','FALSE');
use Gtk3 -init;
use JSON;
use Path::Tiny;
use Data::Dumper;


# detect platform - not used, but part of making this cross-platform later
my $platform = $^O;
print "Running NixieClock on $platform\n";

# load configuration
my $config;
my $configfile = "$ENV{'HOME'}/.config/NixieClock/nixieclock.json";
if (! -e $configfile) {
    print STDERR "Error. Unable to find configuration file at the following location:\n";
    print STDERR "    $configfile\n";
    exit 0;
} else {
    my $configdata = path($configfile)->slurp;
    $config = JSON->new->decode($configdata);
    print Dumper($config);
    print "Using image directory: " . $config->{'imagedir'} . "\n";
}

# use system time zone and if not set, use configuration
my $timezone = "";
my $sys_timezonefile = "/etc/timezone";
if (-e $sys_timezonefile and -s $sys_timezonefile) {
    $timezone = path($sys_timezonefile)->slurp;
    chomp($timezone);
    print "Using system time zone : $timezone\n";
}
if (!defined($timezone) or $timezone eq "") {
    $timezone = $config->{'timezone'};
    print "Using clock config time zone : $timezone\n";
}

# load up the image set defined in the config
my $imageconfig;
my $imageset = $config->{'imageset'};
my $imagesetfile = $config->{'imagedir'} . "/nixie_" . $imageset . ".json";
if (! -e $imagesetfile) {
    print STDERR "Error. Unable to find image set \'$imageset\' config file at:\n";
    print STDERR "    $imagesetfile\n";
    exit 0;
} else {
    my $imagedata = do {
        open(my $imageset_fh, "<:encoding(UTF-8)", $imagesetfile) or die("Can't open $imagesetfile : " . $! . "\n");
        local $/;
        <$imageset_fh>
    };
    my $json = JSON->new;
    $imageconfig = $json->decode($imagedata);
    print Dumper($imageconfig);
    print "Using image set $imageset : " . $imageconfig->{'description'} . "\n";
}

# other general variables not in configuration file
my $setdecorated = FALSE;              # no title bar to window
my $doblink = $config->{'imagedir'};   # controls whether we blink the time separator
my $blink = 0;                         # controls off/on cycle of blinking the time spacer
my $imagewidth = $imageconfig->{'imgwidth'};
my $imageheight = $imageconfig->{'imgheight'};
my $scale = $imageconfig->{'scale'};
my $spacing = $imageconfig->{'spacing'};
$imagewidth *= $scale;
$imageheight *= $scale;
my $panel_width = 5;
print "debug - imagewidth: $imagewidth, imageheight: $imageheight\n";

# setup our window and display for positioning the window
my $window = Gtk3::Window->new ('toplevel');

my $screen = $window->get_screen();
print "screen r: " . $screen->get_resolution() . "\n";
print "screen current: " . $screen->get_monitor_at_window($screen->get_active_window()) ."\n";

my $display = $screen->get_display();
print "monitor total: " . $display->get_n_monitors() . "\n";

my $monitor = $display->get_primary_monitor();
print "monitor - primary: make/model: " . $monitor->get_manufacturer() . "/" . $monitor->get_model() . ", \n";
my $screen_area = $monitor->get_geometry();
print "monitor - primary: refresh:" . ($monitor->get_refresh_rate() / 1000) . "Hz, geo: " . $screen_area->{width} . "x" . $screen_area->{height} . ", offset x/y: " . $screen_area->{x} . "/" . $screen_area->{y} . "\n";

$window->set_title("NixieClock");
$window->set_decorated($setdecorated);
$window->set_border_width(0);
$window->signal_connect('delete_event' => sub{ Gtk3::main_quit() });
$window->set_gravity('GDK_GRAVITY_SOUTH_EAST');
$window->set_resizable(FALSE);
#$window->set_default_size($imagewidth*5,$imageheight);
# try to place in bottom right corner of primary display by default - note the window manager ultimately
# decides where this is placed, as other things on the desktop can prevent it getting placed accordingly
my $windowplacex = ($screen_area->{width}+$screen_area->{x})-(($imagewidth * ($panel_width-1))+($imagewidth)+($spacing * 4));
my $windowplacey = ($screen_area->{height}+$screen_area->{y}) - $imageheight;
$window->move($windowplacex, $windowplacey);
#$window->signal_connect('motion_notify_event' => sub{ \&hoverover() }); # works for hovering over - will use later for something
#$window->signal_connect('configure-event' => sub{ \&configure() }); # works for moving window - will use later

# load up images for the chosen set
#$imageconfig->{'base_set'}{"spacer_on"} = "hello";
while (my ($key, $val) = each(%{$imageconfig->{'base_set'}}) ) {
    print "debug - key: $key, val: $val\n";
    $imageconfig->{'base_set'}{$key} = Gtk3::Gdk::Pixbuf->new_from_file_at_size($config->{'imagedir'}."/nixie_${imageset}-$val.png", $imagewidth, $imageheight);
}

# get current time and pack our timebox with the appropriate digit image
my $time = DateTime->now()->set_time_zone($timezone);
my $tooltip = "<span foreground='orange'>" . $time->day_name ." " . $time->day . " " . $time->month_name . " " . $time->year . "</span>";

my $hourdigit1 = int($time->hour / 10);
my $hourdigit2 = int($time->hour % 10);
my $minutedigit1 = int($time->minute / 10);
my $minutedigit2 = int($time->minute % 10);


# set up a container for the images so theres some signal detection (hover over for example)
my $eventbox = Gtk3::EventBox->new();
$eventbox->set_above_child(TRUE);
$eventbox->set_visible_window(FALSE);
$eventbox->set_has_tooltip(TRUE);
$eventbox->set_border_width(0);
$eventbox->set_tooltip_markup($tooltip);

# format images horizontally
my $timebox = Gtk3::Box->new('horizontal', 0);

my $hourdigit1_img = Gtk3::Image->new();
   $hourdigit1_img->set_from_pixbuf($imageconfig->{'base_set'}{$hourdigit1});
$timebox->pack_start($hourdigit1_img, FALSE, FALSE, $spacing);

my $hourdigit2_img = Gtk3::Image->new();
   $hourdigit2_img->set_from_pixbuf($imageconfig->{'base_set'}{$hourdigit2});
$timebox->pack_start($hourdigit2_img, FALSE, FALSE, $spacing);

my $spacer_img = Gtk3::Image->new();
$spacer_img->set_from_pixbuf($imageconfig->{'base_set'}{"spacer_off"});
$timebox->pack_start($spacer_img, FALSE, FALSE, $spacing);

my $minutedigit1_img = Gtk3::Image->new();
   $minutedigit1_img->set_from_pixbuf($imageconfig->{'base_set'}{$minutedigit1});
$timebox->pack_start($minutedigit1_img, FALSE, FALSE, $spacing);

my $minutedigit2_img = Gtk3::Image->new();
   $minutedigit2_img->set_from_pixbuf($imageconfig->{'base_set'}{$minutedigit2});
$timebox->pack_start($minutedigit2_img, FALSE, FALSE, 0);

# pull everything together
$eventbox->add($timebox);
$window->add($eventbox);
$window->show_all;

# register our timers - for now check for a time change every 1000ms (1 second)
my $clocktimer = Glib::Timeout->add(1000, \&updatetime);

# enter the GTK3 main loop
Gtk3::main;

exit;


# get current time and update any images that need changing
sub updatetime {
    
    my $updatetime = DateTime->now()->set_time_zone($timezone);
    my $tooltip = "<span foreground='orange'>" . $updatetime->day_name ." " . $updatetime->day . " " . $updatetime->month_name . " " . $updatetime->year . "</span>";
    $eventbox->set_tooltip_markup($tooltip);
    my $updatehourdigit1 = int($updatetime->hour / 10);
    my $updatehourdigit2 = int($updatetime->hour % 10);
    my $updateminutedigit1 = int($updatetime->minute / 10);
    my $updateminutedigit2 = int($updatetime->minute % 10);
    
    if ($updateminutedigit1 != $minutedigit1) {
        $minutedigit1_img->set_from_pixbuf($imageconfig->{'base_set'}{$updateminutedigit1});
        $minutedigit1 = $updateminutedigit1;
    }
    if ($updateminutedigit2 != $minutedigit2) {
        $minutedigit2_img->set_from_pixbuf($imageconfig->{'base_set'}{$updateminutedigit2});
        $minutedigit2 = $updateminutedigit2;
    }
    if ($updatehourdigit1 != $hourdigit1) {
        $hourdigit1_img->set_from_pixbuf($imageconfig->{'base_set'}{$updatehourdigit1});
        $hourdigit1 = $updatehourdigit1;
    }
    if ($updatehourdigit2 != $hourdigit2) {
        $hourdigit2_img->set_from_pixbuf($imageconfig->{'base_set'}{$updatehourdigit2});
        $hourdigit2 = $updatehourdigit2;
    }
    # blinking the separator is simply toggling the blink boolean each call
    if ($doblink) {
        $blink = !$blink;
        if ($blink) {
            $spacer_img->set_from_pixbuf($imageconfig->{'base_set'}{"spacer_on"});
        } else {
            $spacer_img->set_from_pixbuf($imageconfig->{'base_set'}{"spacer_off"});
        }
    }
    
    return TRUE;
}