/********************************************************************
# Copyright 2015 Daniel 'grindhold' Brendle
#
# This file is part of libhttpseverywhere.
#
# libhttpseverywhere is free software: you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation, either
# version 3 of the License, or (at your option) any later
# version.
#
# libhttpseverywhere is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with libhttpseverywhere.
# If not, see http://www.gnu.org/licenses/.
*********************************************************************/

namespace HTTPSEverywhere {
    private bool initialized = false;
    private Gee.HashMap<Target, Ruleset> rulesets;

    /**
     * This function initializes HTTPSEverywhere by loading
     * the rulesets from the filesystem.
     */
    public void init() {
        rulesets = new Gee.HashMap<Target, Ruleset>();
        load_rulesets();
        initialized = true;
    }

    /**
     * Takes an @url and returns the appropriate
     * HTTPS-enabled counterpart if there is any
     */
    public string rewrite(string url) {
        if (!initialized){
            critical("HTTPSEverywhere was not initialized");
            return url;
        }
        Ruleset? rs = null;
        foreach (Target target in rulesets.keys) {
            if (target.matches(url)) {
                rs = rulesets.get(target);
                break;
            }
        }
        if (rs == null)
            return url;
        else 
            return rs.rewrite(url);
    }

    /**
     * Returns true when there is a #Ruleset for the
     * given URL
     */
    public bool has_https(string url) {
        if (!initialized){
            critical("HTTPSEverywhere was not initialized");
            return false;
        }
        foreach (Target target in rulesets.keys)
            if (target.matches(url))
                return true;
        return false;
    }

    /**
     * Locates all rulesets that can be found in the system
     * And causes them to be parsed into ram.
     */
    private void load_rulesets() {
        var rulepaths = new Gee.HashMap<string, string>();
        var datapaths = new Gee.ArrayList<string>();

        // Specify the paths to search for rules in 
        foreach (string dp in Environment.get_system_data_dirs())
            datapaths.add(dp);
        datapaths.add(Environment.get_user_data_dir());

        // Collects rules throughout the system
        foreach (string dir in datapaths) {
            string ruledirpath = Path.build_filename(dir, "libhttpseverywhere", "rules");
            Dir ruledir;
            try {
                ruledir = Dir.open (ruledirpath);
            } catch (FileError e) {
                continue;
            }
            string? rule = null;
            while ((rule = ruledir.read_name()) != null) {
                rulepaths.set(rule, Path.build_filename(ruledirpath, rule));
            }
        }

        // Cause each rule to be parsed and loaded
        foreach (string rulepath in rulepaths.values) {
            if (!rulepath.has_suffix(".xml"))
                continue;
            parse_ruleset(rulepath);
        }
    }

    /**
     * Causes a new #Ruleset to be created from the
     * file at @rulepath and to be stored in this libs memory
     */
    private void parse_ruleset(string rulepath) {
        Xml.Doc* doc = Xml.Parser.parse_file(rulepath); 
        if (doc == null) {
            warning("Could not parse %s".printf(rulepath));
            return;
        }

        Xml.Node* root = doc->get_root_element();
        if (root != null) {
            try {
                var rs = new Ruleset.from_xml(root);
                foreach (Target target in rs.targets)
                    rulesets.set(target, rs);
            } catch (RulesetError e) {
            }
        } else {
            warning("No Root element in %s".printf(rulepath));
        }

        delete doc;
    }

    /**
     * Returns only the host-part of @url 
     */
    private string extract_host(string url) {
        var uri = Xml.URI.parse(url);
        return uri.server;
    }
}
