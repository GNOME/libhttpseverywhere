namespace HTTPSEverywhere {
    public errordomain RulesetError {
        PARSE_ERROR // Gets thrown when a ruleset fails to parse
    }

    public class Ruleset : GLib.Object {
        private string name;
        private string platform;
        private bool default_off;

        private Gee.ArrayList<Rule> rules;
        private Gee.ArrayList<string> exclusions;
        private Gee.ArrayList<string> _targets;
        public Gee.ArrayList<string> targets {
            get {
                return this._targets;
            }
        }
        private string securecookie;

        public Ruleset() {
            this.rules = new Gee.ArrayList<Rule>();
            this.exclusions = new Gee.ArrayList<string>();
            this._targets = new Gee.ArrayList<string>();
        }

        public Ruleset.from_xml(Xml.Node* root) throws RulesetError {
            this();
            if (root->name != "ruleset")
                throw new RulesetError.PARSE_ERROR("Name of rootnode must be 'ruleset'");
            
            // Set the Rulesets attributes
            string? n = root->get_prop("name");
            string? m;
            if (n != null)
                this.name = n;
            n = root->get_prop("default_off");
            this.default_off = n != null;
            n = root->get_prop("platform");
            if (n != null)
                this.platform = n;

            for (Xml.Node* cn = root->children; cn != null; cn = cn->next) {
                if (cn->type != Xml.ElementType.ELEMENT_NODE)
                    continue;
                switch (cn->name) {
                    case "rule":
                        n = cn->get_prop("from");
                        m = cn->get_prop("to");
                        if (n == null || m == null)
                            warning("Skipped malformed rule");
                        else
                            this.add_rule(n,m);
                        break;
                    case "target":
                        n = cn->get_prop("host");
                        if (n != null)
                            this.add_target(n);
                        else
                            warning("Skipped malformed target");
                        break;
                    case "exclusion":
                        n = cn->get_prop("pattern");
                        if (n != null)
                            this.add_exclusion(n);
                        else
                            warning("Skipped malformed exclusion");
                        break;
                    case "securecookie":
                        n = cn->get_prop("host");
                        if (n != null)
                            this.securecookie =  n;
                        else
                            warning("Skipped malformed securecookie");
                        break;
                    default:
                        warning("Unknown node found: %s".printf(cn->name));
                        break;
                }
            }
        }

        public void add_rule(string from, string to) {
            this.rules.add(new Rule(from, to));
        }

        public void add_exclusion(string exclusion) {
            this.exclusions.add(exclusion);
        }

        public void add_target(string host) {
            this.targets.add(host);
        }
    }

    private class Rule : GLib.Object {
        private Regex from;
        private string to = "";

        public Rule (string from, string to) {
            this.from = new Regex(from);
        }

        public string rewrite(string url) {
            MatchInfo info;
            if (this.from.match(url, 0, out info)) {
                string ret = this.to;
                for (int i = 1; i < info.get_match_count(); i++) {
                    stdout.printf("replacing %d match %s\n", i, info.fetch(i));
                    ret = ret.replace("$%d".printf(i),info.fetch(i));
                }
                return ret;
            } else
                return url;
        }
    }
}
