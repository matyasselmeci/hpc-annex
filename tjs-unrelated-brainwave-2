In terms of (the idea about) pulling resource requests rather than pushing them (to replace glide-ins),

to get the resource requests (autoclusters) to the collector, how about adding the autoclusters
as nested ads of the submitter ads?  The resource requests should (maybe need) to have the submitter
information anyway, and doing this in the schedd means that we don't have to do anything (else) to
send the resource requests to the collector.  Additionally, if we use the same syntax for the nested
autoclusters as we do for heterogeneous GPUs, we can just call `evalInEachContext()` to determine if
any of our local machine( ads) match the resource request!
