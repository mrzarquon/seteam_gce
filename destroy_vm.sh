#!/bin/bash

gcutil deleteinstance puppetmaster-1a -f --delete_boot_pd
gcutil deleteinstance puppetagent-1a -f --delete_boot_pd
gcutil deleteinstance puppetagent-2a -f --delete_boot_pd
