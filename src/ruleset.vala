namespace HTTPSEverywhere {
    public class Ruleset : GLib.Object {
        private Rule[] rules;
        public Ruleset() {
        }

        public Ruleset.from_xml() {
        }
    }

    private class Rule : GLib.Object {
        private string from = "";
        private string to = "";

        public Rule (string from, string to) {
        }

        public string httpsify(string url) {
            return url;
        }
    }
}
