# LibreOffice - Free office suite
#
# Purpose: Comprehensive, professional-quality productivity suite
# Platform: Linux (via nixpkgs)
# Website: https://www.libreoffice.org/
#
# Features:
#   - Writer, Calc, Impress, Draw, Base, Math
#   - Microsoft Office compatibility
#   - ODF (Open Document Format) native support
#   - PDF export with advanced features
#
# Sources:
#   - https://www.libreoffice.org/
{pkgs, ...}: {
  home.packages = [pkgs.libreoffice-fresh];

  home.shellAliases = {
    lo = "libreoffice";
    lowriter = "libreoffice --writer";
    localc = "libreoffice --calc";
    loimpress = "libreoffice --impress";
    lodraw = "libreoffice --draw";
  };
}
