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

using HTTPSEverywhere;

namespace HTTPSEverywhereTest {
    class Main {
        public static int main (string[] args) {
            Test.init(ref args);
            ContextTest.add_tests();
            RulesetTest.add_tests();
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
            Test.add_func("/httpseverywhere/context/rewrite_async", () => {
                var loop = new MainLoop();
                var context = new Context();
                context.init();
                context.rewrite.begin("http://example.com", (obj, res) => {
                    var result = context.rewrite.end(res);
                    assert(result == "http://example.com/" || result == "https://example.com/");
                    loop.quit();
                });
                loop.run();
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
        }
    }
}
