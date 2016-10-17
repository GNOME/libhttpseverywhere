/********************************************************************
# Copyright 2015-2016 Daniel 'grindhold' Brendle
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

    private const string rulesets_file = "rulesets.json";

    /**
     * The library context object. Most applications will only need to create a
     * single context.
     */
    public class Context {
        private Json.Parser parser;
        private bool initialized = false;

        private RewriteResult last_rewrite_state;
        private Gee.HashMap<Target, Gee.ArrayList<uint>> targets;
        private Gee.HashMap<uint, Ruleset> rulesets;

        /* This class is a workaround to allow using a delegate with a target as
         * a generic. This is horrible, but it's easier than fixing Vala.
         */
        private class InitCompleteCallback {
            public delegate void Callback();

            public InitCompleteCallback(Callback callback) {
                this.callback = () => {
                    callback();
                };
            }

            public Callback callback;
        }

        private Gee.Queue<InitCompleteCallback> init_complete_callbacks;

        /**
         * Different states that express what a rewrite process did to
         * a URL
         */
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
         * Create a new library context object.
         */
        public Context() {
            init_complete_callbacks = new Gee.ArrayQueue<InitCompleteCallback>();
        }

        private void execute_init_complete_callbacks() {
            while (!init_complete_callbacks.is_empty)
                init_complete_callbacks.poll().callback();
        }

        /**
         * This function initializes HTTPSEverywhere by loading
         * the rulesets from the filesystem.
         */
        public async void init() {
            initialized = false;

            targets = new Gee.HashMap<Target,Gee.ArrayList<uint>>();
            rulesets = new Gee.HashMap<int, Ruleset>();

            var datapaths = new Gee.ArrayList<string>();

            // Specify the paths to search for rules in
            datapaths.add(Path.build_filename(Environment.get_user_data_dir(),
                                              "libhttpseverywhere", rulesets_file));
            foreach (string dp in Environment.get_system_data_dirs())
                datapaths.add(Path.build_filename(dp, "libhttpseverywhere", rulesets_file));

            parser = new Json.Parser();
            bool success = false;

            foreach (string dp in datapaths) {
                try {
                    File f = File.new_for_path(dp);
                    DataInputStream dis = new DataInputStream(f.read());
                    yield parser.load_from_stream_async(dis);
                } catch(GLib.Error e) { continue; }
                success = true;
                break;
            }
            if (!success) {
                string locations = "\n";
                foreach (string location in datapaths)
                    locations += "%s\n".printf(location);
                critical("Could not find any suitable database in the following locations:%s",
                         locations);
                execute_init_complete_callbacks();
                return;
            }

            load_targets();
            initialized = true;
            execute_init_complete_callbacks();
        }

        /**
         * Obtain the RewriteResult for the last rewrite that
         * has been done with HTTPSEverywhere.rewrite(string url)
         */
        public RewriteResult rewrite_result() {
            return last_rewrite_state;
        }

        /**
         * Takes a url and returns the appropriate
         * HTTPS-enabled counterpart if there is any
         */
        public async string rewrite(string p_url) {
            string url = p_url;

            if (!url.has_prefix("http://"))
                return url;

            if (!initialized) {
                init_complete_callbacks.offer(new InitCompleteCallback(() => {
                    rewrite.callback();
                }));
                yield;
            };

            if (url.has_prefix("http://") && !url.has_suffix("/")) {
                var rep = url.replace("/","");
                if (url.length - rep.length <= 2)
                    url += "/";
            }
            Ruleset? rs = null;
            foreach (Target target in targets.keys) {
                if (target.matches(url)) {
                    foreach (uint ruleset_id in targets.get(target)) {
                        if (!rulesets.has_key(ruleset_id))
                            load_ruleset(ruleset_id);
                        rs = rulesets.get(ruleset_id);
                    }
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
         * Takes a url and returns the appropriate
         * HTTPS-enabled counterpart if there is any.
         * May block for a relatively long time. It is
         * a programmer error to call this before init().
         */
        public string rewrite_sync(string url) {
            var main_loop = new MainLoop();
            var result = "";

            rewrite.begin(url, (obj, res) => {
                result = rewrite.end(res);
                main_loop.quit();
            });
            main_loop.run();

            return result;
        }

        /**
         * Returns true when there is a {@link HTTPSEverywhere.Ruleset} for the
         * given URL
         */
        public async bool has_https(string url) {
            assert(initialized);
            if (!initialized){
                init_complete_callbacks.offer(new InitCompleteCallback(() => {
                    has_https.callback();
                }));
                yield;
            }
            foreach (Target target in targets.keys)
                if (target.matches(url))
                    return true;
            return false;
        }

        /**
         * Takes a url and returns true if there is an appropriate
         * HTTPS-enabled counterpart of it. It is
         * a programmer error to call this before init().
         */
        public bool has_https_sync(string url) {
            var main_loop = new MainLoop();
            var result = false;

            has_https.begin(url, (obj, res) => {
                result = has_https.end(res);
                main_loop.quit();
            });
            main_loop.run();

            return result;
        }

        /**
         * Loads all possible targets into memory
         */
        private void load_targets() {
            Json.Node root = parser.get_root();
            if (root.get_node_type() != Json.NodeType.OBJECT) {
                error("Need an object as the rootnode of rulesets.");
            }
            var rootobj = root.get_object();

            if (!rootobj.has_member("targets") ||
                    rootobj.get_member("targets").get_node_type() != Json.NodeType.OBJECT) {
                error("The root object must have an object with the name 'targets'.");
            }

            rootobj.get_member("targets").get_object().foreach_member((obj, host, member) => {
                if (member.get_node_type() != Json.NodeType.ARRAY) {
                    error("Targets must supply their ruleset IDs as arrays of integers.");
                }
                var id_list = new Gee.ArrayList<uint>();
                member.get_array().foreach_element((arr,index,element) => {
                    if (element.get_node_type() != Json.NodeType.VALUE)
                        error ("RulesetIDs must be supplied as integer values");
                    id_list.add((uint)element.get_int());
                });
                targets.set(new Target(host), id_list);
            });
        }

        /**
         * Loads a ruleset from the database and stores it in the ram cache
         */
        private void load_ruleset(uint ruleset_id) {
            Json.Node root = parser.get_root();
            if (root.get_node_type() != Json.NodeType.OBJECT) {
                error("Need an object as the rootnode of rulesets.");
            }
            var rootobj = root.get_object();

            if (!rootobj.has_member("rulesetStrings")) {
                error("The root object must have an array with the name 'rulesetStrings'.");
            }

            Json.Node arrnode = rootobj.get_member("rulesetStrings");
            if (arrnode.get_node_type() != Json.NodeType.ARRAY) {
                error("rulesetStrings must be supplied as array of string");
            }

            var arr = arrnode.get_array();
            parse_ruleset(ruleset_id,arr.get_string_element(ruleset_id));
        }

        /**
         * Causes a new {@link HTTPSEverywhere.Ruleset} to be created from the
         * file at rulepath and to be stored in this libs memory
         */
        private void parse_ruleset(uint id, string ruledata) {
            Xml.Doc* doc = Xml.Parser.parse_doc(ruledata);
            if (doc == null) {
                warning("Could not parse rule with id %u".printf(id));
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
                warning("No Root element in rule with id %u".printf(id));
            }

            delete doc;
        }
    }
}
