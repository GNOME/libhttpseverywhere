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
    private Sqlite.Database? db = null;

    private RewriteResult last_rewrite_state;
    private Gee.HashMap<Target, int> targets;
    private Gee.HashMap<int, Ruleset> rulesets;

    public enum RewriteResult {
        /**
         * The URL has successfully been rewritten to HTTPS
         */
        OK,
        /**
         * There was a ruleset for the host but no rule matched
         * for the given URL
         */
        NO_MATCH,
        /**
         * There is no ruleset for the given host
         */
        NO_RULESET
    }

    /**
     * This function initializes HTTPSEverywhere by loading
     * the rulesets from the filesystem.
     */
    public void init() {
        targets = new Gee.HashMap<Target, int>();
        rulesets = new Gee.HashMap<int, Ruleset>();

        var datapaths = new Gee.ArrayList<string>();

        // Specify the paths to search for rules in
        datapaths.add(Path.build_filename(Environment.get_user_data_dir(),
                                          "libhttpseverywhere", "rulesets.sqlite"));
        foreach (string dp in Environment.get_system_data_dirs())
            datapaths.add(Path.build_filename(dp, "libhttpseverywhere", "rulesets.sqlite"));

        int db_status = Sqlite.ERROR;
        foreach (string dp in datapaths) {
            db_status = Sqlite.Database.open(dp, out db);
            if (db_status == Sqlite.OK)
                break;
        }
        if (db_status != Sqlite.OK) {
            string locations = "\n";
            foreach (string location in datapaths)
                locations += "%s\n".printf(location);
            critical("Could not find any suitable database in the following locations:%s",
                     locations);
            return;
        }

        load_targets();
        initialized = true;
    }

    /**
     * Obtain the RewriteResult for the last rewrite that
     * has been done with HTTPSEverywhere.rewrite(string url)
     */
    public RewriteResult rewrite_result() {
        return last_rewrite_state;
    }

    /**
     * Takes an @url and returns the appropriate
     * HTTPS-enabled counterpart if there is any
     */
    public string rewrite(owned string url) {
        if (!initialized){
            critical("HTTPSEverywhere was not initialized");
            return url;
        }
        if (!url.has_suffix("/"))
            url += "/";
        Ruleset? rs = null;
        foreach (Target target in targets.keys) {
            if (target.matches(url)) {
                int ruleset_id = targets.get(target);
                if (!rulesets.has_key(ruleset_id))
                    load_ruleset(ruleset_id);
                rs = rulesets.get(ruleset_id);
                break;
            }
        }
        if (rs == null) {
            last_rewrite_state = RewriteResult.NO_RULESET;
            return url;
        } else {
            last_rewrite_state = RewriteResult.NO_MATCH;
            string rurl = rs.rewrite(url);
            if (url.has_prefix("https://"))
                last_rewrite_state = RewriteResult.OK;
            return rs.rewrite(rurl);
        }
    }

    /**
     * Returns true when there is a #Ruleset for the
     * given URL
     */
    public bool has_https(string url) {
        assert(initialized);
        if (!initialized){
            critical("HTTPSEverywhere was not initialized");
            return false;
        }
        foreach (Target target in targets.keys)
            if (target.matches(url))
                return true;
        return false;
    }

    private const string QRY_TARGETS = "SELECT host, ruleset_id FROM targets;";

    /**
     * Loads all possible targets into the ram
     */
    private void load_targets() {
        Sqlite.Statement stmnt;
        int err = db.prepare_v2(QRY_TARGETS, QRY_TARGETS.length, out stmnt);
        if (err != Sqlite.OK) {
            critical("Could not parse QRY_TARGETS");
            return;
        }
        string host;
        int ruleset_id;
        while (stmnt.step() == Sqlite.ROW) {
            host = stmnt.column_text(0);
            ruleset_id = stmnt.column_int(1);
            targets.set(new Target(host), ruleset_id);
        }
    }

    private const string QRY_RULESET = """
        SELECT contents FROM rulesets WHERE id = $RID;
    """;

    /**
     * Loads a ruleset from the database and stores it in the ram cache
     */
    private void load_ruleset(int ruleset_id) {
        Sqlite.Statement stmnt;
        int err = db.prepare_v2(QRY_RULESET, QRY_RULESET.length, out stmnt);
        if (err != Sqlite.OK) {
            critical("Could not parse QRY_RULESET");
            return;
        }
        int id_param_pos = stmnt.bind_parameter_index("$RID");
        assert (id_param_pos > 0);
        stmnt.bind_int(id_param_pos, ruleset_id);
        if (stmnt.step() == Sqlite.ROW) {
            string ruleset = stmnt.column_text(0);
            parse_ruleset(ruleset_id, ruleset);
        } else
            warning("Could not find ruleset for ID. This indicates that there" +
                    " is a ruleset missing though it is referenced by a target.");
    }

    /**
     * Causes a new #Ruleset to be created from the
     * file at @rulepath and to be stored in this libs memory
     */
    private void parse_ruleset(int id, string ruledata) {
        Xml.Doc* doc = Xml.Parser.parse_doc(ruledata);
        if (doc == null) {
            warning("Could not parse rule with id %d".printf(id));
            return;
        }

        Xml.Node* root = doc->get_root_element();
        if (root != null) {
            try {
                var rs = new Ruleset.from_xml(root);
                rulesets.set(id, rs);
            } catch (RulesetError e) {
            }
        } else {
            warning("No Root element in rule with id %d".printf(id));
        }

        delete doc;
    }
}
