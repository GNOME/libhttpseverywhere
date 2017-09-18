/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/********************************************************************
# Copyright 2015-2017 Daniel 'grindhold' Brendle
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
        private Xml.Doc* ruleset_xml;

        private RewriteResult last_rewrite_state;
        private Gee.HashMap<Target, Gee.ArrayList<uint>> targets;
        private Gee.HashMap<uint, Ruleset> rulesets;

        // Cache for recently used targets
        private Gee.ArrayList<Target> cache;
        private const int CACHE_SIZE = 100;

        // List of RulesetIds that are to be ignored
        private Gee.ArrayList<uint> ignore_list;

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
            try {
                new Thread<int>.try("rulesets", this.init);
            } catch (Error e) {
                warning("Could not initialize HTTPSEverywhere: %s", e.message);
            }
        }

        /**
         * Initialization finished
         *
         * This signal is being triggered when all ruesets have
         * been loaded into memory and the context can subsequently
         * be asked to perform queries on HTTPSEverywheres data.
         */
        public signal void rdy(Error? e);

        /**
         * This function initializes HTTPSEverywhere by loading
         * the rulesets from the filesystem.
         */
        private int init() {
            lock (this.initialized) {
                IOError e;
                try {
                    initialized = false;

                    targets = new Gee.HashMap<Target,Gee.ArrayList<uint>>();
                    rulesets = new Gee.HashMap<int, Ruleset>();
                    cache = new Gee.ArrayList<Target>();

                    ignore_list = new Gee.ArrayList<uint>();

                    var datapaths = new Gee.ArrayList<string>();

                    // Specify the paths to search for rules in
                    datapaths.add(Path.build_filename(Environment.get_user_data_dir(),
                                                      "libhttpseverywhere", rulesets_file));
                    foreach (string dp in Environment.get_system_data_dirs())
                        datapaths.add(Path.build_filename(dp, "libhttpseverywhere", rulesets_file));

                    // local rules in repo dir to test data without installation
                    datapaths.add(Path.build_filename(Environment.get_current_dir(), "..", "data", rulesets_file));

                    bool success = false;

                    foreach (string dp in datapaths) {
                        this.ruleset_xml = Xml.Parser.parse_file(dp);
                        if (this.ruleset_xml == null)
                            continue;
                        success = true;
                        break;
                    }
                    if (!success) {
                        string locations = "\n";
                        foreach (string location in datapaths)
                            locations += "%s\n".printf(location);
                        critical("Could not find any suitable database in the following locations:%s",
                                 locations);
                        return 1;
                    }
                    this.load_rulesets();
                    initialized = true;
                } catch (IOError e) {
                    GLib.Idle.add(()=>{this.rdy(e); return false;});
                    return 1;
                }
            }
            GLib.Idle.add(()=>{this.rdy(null); return false;});
            return 0;
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
                if (target.matches(url_copy)) {
                    foreach (uint ruleset_id in targets.get(target)) {
                        if (ruleset_id in this.ignore_list)
                            continue;

                        /*if (!rulesets.has_key(ruleset_id))
                            load_ruleset(ruleset_id);*/

                        rs = rulesets.get(ruleset_id);
                    }
                    break;
                }
            }

            if (rs == null) {
                foreach (Target target in targets.keys) {
                    if (target.matches(url_copy)) {
                        foreach (uint ruleset_id in targets.get(target)) {
                            if (ruleset_id in this.ignore_list)
                                continue;

                            /*if (!rulesets.has_key(ruleset_id))
                                load_ruleset(ruleset_id);*/

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
         * Tells this context to ignore the ruleset with the given id
         * @since 0.4
         */
        public void ignore_ruleset(uint id) {
            this.ignore_list.add(id);
        }

        /**
         * Tells this context to check for a previously ignored ruleset again
         * @since 0.4
         */
        public void unignore_ruleset(uint id) {
            if (id in this.ignore_list)
                this.ignore_list.remove(id);
        }

        /**
         * Tells this context to ignore the given host
         * @since 0.4
         */
        public void ignore_host(string host) {
            throw new ContextError.NOT_IMPLEMENTED("Context.ignore_host ist not implemented yet.");
        }

        /**
         * Tells this context to check for a previously ignored host again
         * @since 0.4
         */
        public void unignore_host(string host) {
            throw new ContextError.NOT_IMPLEMENTED("Context.unignore_host ist not implemented yet.");
        }

        private void load_rulesets() {
            Xml.Node* root = this.ruleset_xml->get_root_element();
            if (root->name != "rulesetlibrary") {
                error("The root element of a ruleset-library must be named 'rulesetlibrary'");
            }
            uint id = 0;
            Xml.Node* cn;
            for (cn = root->children; cn != null; cn = cn->next) {
                if (cn->type != Xml.ElementType.ELEMENT_NODE || cn->name != "ruleset")
                    continue;
                try {
                    var rs = new Ruleset.from_xml(cn);
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
                }
            }
            delete cn;
            delete root;
        }
    }
}
