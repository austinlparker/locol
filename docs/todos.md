# Project Ideas

1. Reduce complexity by only supporting a single collector at once

Currently, the app kinda does a lot of stuff to handle the idea of each collector being switch-toable or even running at the same time. However, what if we simplified the 
architecture to have a 1:1 relationship between collector configs and app instances? This would be a pretty big refactor of the data model but it would be much simpler - each 
window would only have a single collector config, instance, collector version, etc. 

This would allow us to consolidate quite a bit of our model logic; We could have a single Collector model and it could encapsulate quite a bit of functionality.
