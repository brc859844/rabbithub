#!/bin/bash
#simple way to convert dos files to unix files (useful when cut and paste between environment corrupts file)
sed -i -e 's/\r$//' $1
