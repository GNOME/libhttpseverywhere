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

using HTTPSEverywhere;

namespace HTTPSEverywhereTest {
    class Main {
        public static int main (string[] args) {
            Test.init(ref args);
            ContextTest.add_tests();
            RulesetTest.add_tests();
            UpdaterTest.add_tests();
            Test.run();
            return 0;
        }
    }

    class ContextTest {
        /* Note that Context tests do not check if a particular URI has been
         * rewritten, because we don't want the tests to be dependent on
         * changing rulesets.
         */
        public static void add_tests () {
            Test.add_func("/httpseverywhere/context/rewrite", () => {
                var context = new Context();
                var m = new MainLoop();
                context.init.begin(null, (obj, res) => {
                    try {
                        context.init.end(res);
                        var result = context.rewrite("http://example.com");
                        assert(result == "http://example.com/" || result == "https://example.com/");
                        assert(context.has_https("http://example.com") == result.has_prefix("https://"));
                        m.quit();
                    } catch (Error e) {
                        GLib.assert_not_reached();
                    }
                });
                m.run();
            });

            Test.add_func("/httpseverywhere/context/cancel_init", () => {
                var loop = new MainLoop();
                var context = new Context();
                var cancellable = new Cancellable();

                context.init.begin(cancellable, (obj, res) => {
                    try {
                        context.init.end(res);
                        assert_not_reached();
                    } catch (Error e) {
                        assert(e is IOError.CANCELLED);
                        assert(cancellable.is_cancelled());
                        loop.quit();
                    }
                });

                cancellable.cancel();
                loop.run();
            });

            Test.add_func("/httpseverywhere/context/rewrite_before_init", () => {
                if (Test.subprocess()) {
                    /* Should emit a critical since init has not been called. */
                    new Context().rewrite("http://example.com");
                }

                Test.trap_subprocess(null, 0, 0);
                Test.trap_assert_failed();
                Test.trap_assert_stderr("*CRITICAL*");
            });
        }
    }

    class RulesetTest {
        public static void add_tests () {
            Test.add_func("/httpseverywhere/ruleset/simple", () => {
                var from = "^http:";
                var to   = "https:";
                var url  = "http://blog.fefe.de";

                var ruleset = new Ruleset();
                ruleset.add_rule(from, to);

                assert (ruleset.rewrite(url) == "https://blog.fefe.de");
            });

            Test.add_func("/httpseverywhere/ruleset/1group", () => {
                var from = "^http://(en|fr)wp\\.org/";
                var to   = "https://$1.wikipedia.org/wiki/";
                var url  = "http://enwp.org/Tamale";

                var ruleset = new Ruleset();
                ruleset.add_rule(from, to);

                assert (ruleset.rewrite(url) == "https://en.wikipedia.org/wiki/Tamale");

                url  = "http://frwp.org/Tamale";
                assert (ruleset.rewrite(url) == "https://fr.wikipedia.org/wiki/Tamale");
            });

            Test.add_func("/httpseverywhere/ruleset/optional_subdomain", () => {
                var from = "^http://(?:www\\.)?filescrunch\\.com/";
                var to   = "https://filescrunch.com/";
                var url  = "http://filescrunch.com/nyannyannyannyan";

                var ruleset = new Ruleset();
                ruleset.add_rule(from, to);

                assert (ruleset.rewrite(url) == "https://filescrunch.com/nyannyannyannyan");

                url  = "http://www.filescrunch.com/nyannyannyannyan";
                assert (ruleset.rewrite(url) == "https://filescrunch.com/nyannyannyannyan");
            });

            Test.add_func("/httpseverywhere/ruleset/omitted_replace_fields", () => {
                var from = "^(http://(www\\.)?|https://)(dl|fsadownload|fsaregistration|ifap|nslds|tcli)\\.ed\\.gov/";
                var to   = "https://www.$3.ed.gov/";
                var url  = "http://fsaregistration.ed.gov/";

                var ruleset = new Ruleset();
                ruleset.add_rule(from, to);

                assert (ruleset.rewrite(url) == "https://www.fsaregistration.ed.gov/");

                url  = "http://www.dl.ed.gov/";
                assert (ruleset.rewrite(url) == "https://www.dl.ed.gov/");
            });

            Test.add_func("/httpseverywhere/context/ignore", () => {
                var context = new Context();
                var m = new MainLoop();
                context.init.begin(null, (obj, res) => {
                    try {
                        context.init.end(res);
                        var result = context.rewrite("http://forums.lemonde.fr");
                        assert(result.has_prefix("https://"));
                        context.ignore_host("forums.lemonde.fr");
                        result = context.rewrite("http://forums.lemonde.fr");
                        assert(result.has_prefix("http://"));
                        context.unignore_host("forums.lemonde.fr");
                        result = context.rewrite("http://forums.lemonde.fr");
                        assert(result.has_prefix("https://"));
                        m.quit();
                    } catch (Error e) {
                        GLib.assert_not_reached();
                    }
                });
                m.run();
            });
        }
    }

    class UpdaterTest {
        public static void add_tests () {
            Test.add_func("/httpseverywhere/updater/update", () => {
                var context = new Context();
                context.init.begin(null, (obj, res) => {
                    try {
                        context.init.end(res);
                    } catch (Error e) {
                        GLib.assert_not_reached();
                    }
                });
                var updater = new Updater(context);
                var m = new MainLoop();
                updater.update.begin(null, (obj, res) => {
                    try {
                        updater.update.end(res);
                        m.quit();
                    } catch (UpdateError.NO_UPDATE_AVAILABLE e) {
                        m.quit();
                    } catch (Error e) {
                        GLib.assert_not_reached();
                    }
                });
                m.run();
            });
        }
    }
}
