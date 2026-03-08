# Shared Dock Parsing Library
#
# Purpose: Cross-platform utilities for parsing dock configuration entries
# Usage: Imported by platform-specific dock modules (darwin, gnome)
# Platform: Cross-platform (no platform-specific logic)
#
# Feature: 023-user-dock-config
{lib}: let
  # Entry type detection patterns
  isSystemItem = entry: builtins.match "^<.+>$" entry != null;
  isSeparator = entry: entry == "|" || entry == "||";
  isFolder = entry: lib.hasPrefix "/" entry;
  isApp = entry: !(isSystemItem entry) && !(isSeparator entry) && !(isFolder entry);

  # Parse a single dock entry into structured record
  parseDockEntry = entry:
    if isSystemItem entry
    then {
      type = "system";
      value = builtins.substring 1 (builtins.stringLength entry - 2) entry;
      raw = entry;
    }
    else if isSeparator entry
    then {
      type = "separator";
      value =
        if entry == "||"
        then "thick"
        else "standard";
      raw = entry;
    }
    else if isFolder entry
    then {
      type = "folder";
      value = builtins.substring 1 (builtins.stringLength entry - 1) entry;
      raw = entry;
    }
    else {
      type = "app";
      value = entry;
      raw = entry;
    };

  # Parse all entries in a docked array
  parseDockedList = entries: map parseDockEntry entries;

  # Remove consecutive separators, keeping only the first
  collapseSeparators = entries: let
    result =
      builtins.foldl' (
        acc: entry:
          if entry.type == "separator"
          then
            if acc.prevWasSeparator
            then acc
            else {
              items = acc.items ++ [entry];
              prevWasSeparator = true;
            }
          else {
            items = acc.items ++ [entry];
            prevWasSeparator = false;
          }
      ) {
        items = [];
        prevWasSeparator = false;
      }
      entries;
  in
    result.items;

  # Remove leading and trailing separators
  trimSeparators = entries: let
    # Manual dropWhile implementation (lib.dropWhile not available in older nixpkgs)
    dropWhile = pred: list:
      if list == []
      then []
      else if pred (builtins.head list)
      then dropWhile pred (builtins.tail list)
      else list;

    dropLeading = dropWhile (e: e.type == "separator") entries;
    reversed = lib.reverseList dropLeading;
    dropTrailing = dropWhile (e: e.type == "separator") reversed;
  in
    lib.reverseList dropTrailing;

  # Normalize a parsed dock list
  normalizeParsedList = entries: trimSeparators (collapseSeparators entries);

  # Full parsing pipeline: parse -> normalize
  parseAndNormalize = entries: normalizeParsedList (parseDockedList entries);

  # Filter entries by type
  filterByType = type: entries: lib.filter (e: e.type == type) entries;

  # Check if docked list has any items
  hasDockedItems = entries: entries != [] && entries != null;
in {
  inherit
    parseDockEntry
    parseDockedList
    collapseSeparators
    trimSeparators
    normalizeParsedList
    parseAndNormalize
    filterByType
    hasDockedItems
    isSystemItem
    isSeparator
    isFolder
    isApp
    ;
}
