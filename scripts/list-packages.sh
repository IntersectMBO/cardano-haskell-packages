#!/usr/bin/env bash

find _sources -mindepth 2 -type d | cut --fields=2,3 --delimiter="/" --output-delimiter=" " | sort
