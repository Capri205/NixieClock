# NixieClock

A GTK3 clock that uses nixie tube like images for the digits.

Eventually this will become an xfce4 panel but for now a simple stand-alone perl script.
No bells and whistles yet. Simply puts a clock showing hour:minutes in the bottom
right corner of the primary monitor - no resizing or moving yet. Hover over to get
current date, so just like the clock in your taskbar.

Uses a set of images for the digits and hour-minute separator. 
Image sets have a config file describing the set and the image specificiation.

Key TODO's for this:

- use a function to get values from config hash, so we can report errors and abort - or have an up front check routine
- add dynamic switching of image sets and save selected one back to config
- use a function to get values from config hash, so we can report errors and abort - or have an up front check routine
- when we have user placement in place we can read the saved position data from a file instead
- offset should be driven by actual image width.. caters for separator being different width to digits
- images need quality improvement
- support for variable width images - each digit having it's own image width/height, or a default and then override for specific images like the separators
- add in dynamic resizing of clock like a regular window later
- put images in a grid in a single image file instead of separate images per digit
