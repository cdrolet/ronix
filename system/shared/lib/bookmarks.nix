# Bookmarks - Chromium Bookmarks file generator
#
# Converts user.workspace.bookmarks (Firefox-compatible format) to a valid
# Chromium Bookmarks JSON file with the correct MD5 checksum.
#
# Chromium validates the checksum on startup and will refuse to load a
# Bookmarks file with a wrong checksum. This lib computes the checksum
# using the same algorithm as Chromium (DFS over bookmark_bar → other →
# synced; folder contributes name, URL node contributes name + url).
#
# Usage:
#   bookmarksLib = import ./bookmarks.nix { inherit lib pkgs; };
#   file = bookmarksLib.mkChromiumBookmarksFile config.user.workspace.bookmarks;
#
# Notes:
#   - Separators ("separator") are skipped (not supported in Chromium)
#   - Firefox-only fields (tags, keyword) are ignored
#   - toolbar = true folders go to bookmark_bar (same as non-toolbar items)
#   - Returns a derivation (nix store path) to the final Bookmarks JSON
{ lib, pkgs }:
let
  mkUrlNode = id: item: {
    date_added = "13000000000000000";
    date_last_used = "0";
    guid = "aaaaaaaa-aaaa-4aaa-aaaa-${lib.fixedWidthString 12 "0" (toString id)}";
    id = toString id;
    name = item.name or "";
    type = "url";
    url = item.url;
  };

  mkFolderNode = id: item: children: {
    children = children;
    date_added = "13000000000000000";
    date_last_used = "0";
    date_modified = "13000000000000000";
    guid = "bbbbbbbb-bbbb-4bbb-bbbb-${lib.fixedWidthString 12 "0" (toString id)}";
    id = toString id;
    name = item.name or "";
    type = "folder";
  };

  # Recursively convert user schema items to Chromium nodes, threading an ID counter.
  # Returns { nodes: list, nextId: int }
  convertItems = startId: items:
    builtins.foldl'
    (acc: item:
      if builtins.isString item
      then acc # separators not supported in Chromium
      else if item ? url
      then {
        nodes = acc.nodes ++ [(mkUrlNode acc.nextId item)];
        nextId = acc.nextId + 1;
      }
      else if item ? bookmarks
      then let
        folderId = acc.nextId;
        childResult = convertItems (folderId + 1) (item.bookmarks or []);
      in {
        nodes = acc.nodes ++ [(mkFolderNode folderId item childResult.nodes)];
        nextId = childResult.nextId;
      }
      else acc)
    {
      nodes = [];
      nextId = startId;
    }
    items;

  buildTree = bookmarks: let
    barResult = convertItems 4 bookmarks;
  in {
    roots = {
      bookmark_bar = {
        children = barResult.nodes;
        date_added = "13000000000000000";
        date_last_used = "0";
        date_modified = "13000000000000000";
        guid = "00000000-0000-4000-a000-000000000001";
        id = "1";
        name = "Bookmarks bar";
        type = "folder";
      };
      other = {
        children = [];
        date_added = "13000000000000000";
        date_last_used = "0";
        date_modified = "0";
        guid = "00000000-0000-4000-a000-000000000002";
        id = "2";
        name = "Other bookmarks";
        type = "folder";
      };
      synced = {
        children = [];
        date_added = "13000000000000000";
        date_last_used = "0";
        date_modified = "0";
        guid = "00000000-0000-4000-a000-000000000003";
        id = "3";
        name = "Mobile bookmarks";
        type = "folder";
      };
    };
    version = 1;
  };

  # Computes the Chromium MD5 checksum and writes the final Bookmarks JSON.
  # Algorithm: DFS over bookmark_bar → other → synced.
  #   folder node: MD5Update(name), then recurse children
  #   url node:    MD5Update(name), MD5Update(url)
  checksumScript = pkgs.writeText "chromium-bookmarks-checksum.py" ''
    import hashlib, json, sys

    data = json.loads(sys.argv[1])

    def compute_checksum(roots):
        md5 = hashlib.md5()

        def walk(node):
            name = node.get('name', '')
            if node.get('type') == 'url':
                md5.update(name.encode('utf-8'))
                md5.update(node.get('url', '').encode('utf-8'))
            elif node.get('type') == 'folder':
                md5.update(name.encode('utf-8'))
                for child in node.get('children', []):
                    walk(child)

        for root in ['bookmark_bar', 'other', 'synced']:
            walk(roots[root])

        return md5.hexdigest()

    data['checksum'] = compute_checksum(data['roots'])
    print(json.dumps(data, separators=(',', ':')))
  '';

  # Generate a Brave/Chromium Bookmarks file from user schema bookmarks.
  # Returns a derivation (nix store path) to the JSON file with correct checksum.
  mkChromiumBookmarksFile = bookmarks: let
    treeJson = builtins.toJSON (buildTree bookmarks);
  in
    pkgs.runCommand "Bookmarks" {nativeBuildInputs = [pkgs.python3];} ''
      ${pkgs.python3}/bin/python3 ${checksumScript} ${lib.escapeShellArg treeJson} > $out
    '';
in {
  inherit mkChromiumBookmarksFile;
}
