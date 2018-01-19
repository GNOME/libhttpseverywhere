/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/********************************************************************
# Copyright 2015-2018 Daniel 'grindhold' Brendle
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

/**
 * A set of classes that enables you to use the HTTPS-Everywhere data
 * to convert http-URLs into https-URLs.
 */
namespace HTTPSEverywhere {
    public errordomain ContextError {
        NOT_IMPLEMENTED
    }

    private const string rulesets_file = "default.rulesets";

    /**
     * The library context object. Most applications will only need to create a
     * single context.
     */
    public class Context : GLib.Object {
        private Json.Parser parser;

        private RewriteResult last_rewrite_state;
        private Gee.HashMap<Target, Gee.ArrayList<uint>> targets;
        private Gee.HashMap<uint, Ruleset> rulesets;

        // Cache for recently used targets
        private Gee.ArrayList<Target> cache;
        private const int CACHE_SIZE = 100;

        // List of RulesetIds that are to be ignored
        private Gee.ArrayList<string> ignore_list;

        /**
         * Indicates whether the library has been successfully
         * initialized. Be careful: this property will become //false//
         * at some point if you update the rulesets.
         */
        public bool initialized { get; private set; default = false; }

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
        }

        /**
         * This function initializes HTTPSEverywhere by loading
         * the rulesets from the filesystem.
         */
        public async void init(Cancellable? cancellable = null) throws IOError {
            initialized = false;

            targets = new Gee.HashMap<Target,Gee.ArrayList<uint>>();
            rulesets = new Gee.HashMap<int, Ruleset>();
            cache = new Gee.ArrayList<Target>();

            ignore_list = new Gee.ArrayList<string>();

            var datapaths = new Gee.ArrayList<string>();

            // Specify the paths to search for rules in
            datapaths.add(Path.build_filename(Environment.get_user_data_dir(),
                                              "libhttpseverywhere", rulesets_file));
            foreach (string dp in Environment.get_system_data_dirs())
                datapaths.add(Path.build_filename(dp, "libhttpseverywhere", rulesets_file));

            // local rules in repo dir to test data without installation
            // only works if the test executable is loaded from the build/test folder
            // that meson generates
            if (Environment.get_current_dir().has_suffix("build/test")) {
                datapaths.add(Path.build_filename(Environment.get_current_dir(),
                                                  "..", "..", "data", rulesets_file));
            }

            parser = new Json.Parser();
            bool success = false;

            foreach (string dp in datapaths) {
                try {
                    File f = File.new_for_path(dp);
                    FileInfo fi = f.query_info("standard::*", FileQueryInfoFlags.NONE);
                    if (fi.get_size() == 0) {
                        continue;
                    }
                    FileInputStream fis = yield f.read_async(Priority.DEFAULT, cancellable);
                    DataInputStream dis = new DataInputStream(fis);
                    yield parser.load_from_stream_async(dis, cancellable);
                } catch (Error e) {
                    if (e is IOError.CANCELLED) {
                        throw (IOError) e;
                    }
                    continue;
                }
                success = true;
                break;
            }
            if (!success) {
                string locations = "\n";
                foreach (string location in datapaths)
                    locations += "%s\n".printf(location);
                warning("Could not find any suitable database in the following locations:%s",
                         locations);
                return;
            }

            load_rulesets();
            initialized = true;
        }

        /**
         * Obtain the RewriteResult for the last rewrite that
         * has been done with {@link Context.rewrite}
         */
        public RewriteResult rewrite_result() {
            return last_rewrite_state;
        }

        /**
         * Takes a url and returns the appropriate
         * HTTPS-enabled counterpart if there is any
         */
        public string rewrite(string url)
                requires(initialized) {
            string url_copy = url;

            if (!url_copy.has_prefix("http://"))
                return url_copy;

            if (url_copy.has_prefix("http://") && !url_copy.has_suffix("/")) {
                var rep = url_copy.replace("/","");
                if (url_copy.length - rep.length <= 2)
                    url_copy += "/";
            }
            Ruleset? rs = null;

            foreach (Target target in this.cache) {
                if (target.host in this.ignore_list)
                    continue;

                if (target.matches(url_copy)) {
                    foreach (uint ruleset_id in targets.get(target)) {
                        rs = rulesets.get(ruleset_id);
                    }
                    break;
                }
            }

            if (rs == null) {
                foreach (Target target in targets.keys) {
                    if (target.host in this.ignore_list)
                        continue;

                    if (target.matches(url_copy)) {
                        foreach (uint ruleset_id in targets.get(target)) {
                            rs = rulesets.get(ruleset_id);
                        }
                        if (cache.size >= Context.CACHE_SIZE)
                            cache.remove_at(Context.CACHE_SIZE-1);
                        cache.add(target);
                        break;
                    }
                }
            }

            if (rs == null) {
                last_rewrite_state = RewriteResult.NO_RULESET;
                return url_copy;
            } else {
                last_rewrite_state = RewriteResult.NO_MATCH;
                string rurl = rs.rewrite(url_copy);
                if (url_copy.has_prefix("https://"))
                    last_rewrite_state = RewriteResult.OK;
                return rs.rewrite(rurl);
            }
        }

        /**
         * Returns true when there is a {@link HTTPSEverywhere.Ruleset} for the
         * given URL
         */
        public bool has_https(string url)
                requires(initialized) {
            foreach (Target target in targets.keys)
                if (target.matches(url))
                    return true;
            return false;
        }

        /**
         * Tells once told the context to ignore the ruleset with the given id
         *
         * Ruleset IDs are not a valid concept anymore. Do not use this method.
         * It will have no effect.
         * @since 0.4
         * @deprecated 0.6
         */
        public void ignore_ruleset(uint id) {}

        /**
         * Tells this context to check for a previously ignored ruleset again
         *
         * Ruleset IDs are not a valid concept anymore. Do not use this method.
         * It will have no effect.
         * @since 0.4
         * @deprecated 0.6
         */
        public void unignore_ruleset(uint id) {
        }

        /**
         * Tells this context to ignore the given host
         * @since 0.4
         */
        public void ignore_host(string host) {
            this.ignore_list.add(host);
        }

        /**
         * Tells this context to check for a previously ignored host again
         * @since 0.4
         */
        public void unignore_host(string host) {
            if (host in this.ignore_list)
                this.ignore_list.remove(host);
        }

        /**
         * Loads a ruleset from the database and stores it in the ram cache
         */
        private void load_rulesets() {
            Json.Node root = parser.get_root();

            if (root.get_node_type() != Json.NodeType.ARRAY) {
                warning("Could not parse rulesets: top node must be an array");
            }
            Json.Array rulesets_arr = root.get_array();
            uint id = 0;
            rulesets_arr.foreach_element((_,i,e)=>{
                try {
                    var rs = new Ruleset.from_json(e);
                    rulesets.@set(++id, rs);
                    foreach (Target target in rs.targets) {
                        if (this.targets.has_key(target)) {
                            this.targets.@get(target).add(id);
                        } else {
                            var id_list = new Gee.ArrayList<uint>();
                            id_list.add(id);
                            this.targets.@set(target, id_list);
                        }
                    }
                } catch (RulesetError e) {
                    warning("could not parse a ruleset");
                }
            });
        }
    }
}
