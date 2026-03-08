# Keyboard Layout Registry
#
# This module defines all supported platform-agnostic keyboard layouts.
# Platform-specific translation modules must provide mappings for ALL layouts
# defined here, and must NOT define translations for layouts not listed here.
#
# Constitution: Shared library (Phase 3)
{
  # Supported keyboard layouts with descriptions
  # Platforms must provide translations for all layouts listed here
  layouts = {
    us = "U.S. QWERTY";
    canadian-english = "Canadian English";
    canadian-french = "Canadian French (CSA)";
  };
}
