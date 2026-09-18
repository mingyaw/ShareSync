# M45 Photo Deletion And Reset Policy

Status: Complete source-code checkpoint.

ShareSync does not propagate deletions between phones. If an imported iPhone
photo is removed, its PhotoKit mapping becomes `missing` and is eligible for an
explicit foreground retry while the Android source remains available. Clearing
local history removes ShareSync records and the incremental checkpoint, but it
does not delete Android, iPhone, or iCloud Photos. App deletion removes private
ledgers; imported Photos remain and may be transferred again after reinstall.
