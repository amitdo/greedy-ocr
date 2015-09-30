#
#   greedy-ocr
#   Original Work Copyright (c) 2015 Sebastian Spaar
#-----------------------------------------------------------------------
#   gr_lexicon.sh
#
#   This bash script was used to extract some statistical information
#   from the Mercurius document (the first half, in this case).
#   The first 2 lines create a lexicon containing every word that exists
#   in document, and the 3rd line extracts how often a specific letter
#   occurs in it.

#!/usr/bin/bash
cat mercurius_1st_half.txt | tr -cs "[:alpha:]" "\n" | sort | uniq > raw_lexicon.txt
LC_ALL="de" sort -fd raw_lexicon.txt | uniq > lexicon_1st_half.txt
cat mercurius_1st_half.txt | fold -w1 | sort | uniq -c | sort -k 1nr > letter_frequencies.txt