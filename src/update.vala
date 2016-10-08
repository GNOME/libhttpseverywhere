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
    /**
     * This enumerates states the update passes
     * through. They can be obtained via get_update_state()
     * And used to show informative messages about progress
     * to the user.
     */
    public enum UpdateState {
        FINISHED,
        LOADING_RDF,
        DOWNLOADING_XPI,
        DECOMPRESSING_XPI,
        COPYING_RULES
    }

    /**
     * This enumerates possible results of an update
     */
    public enum UpdateResult {
        SUCCESS,
        NO_UPDATE_AVAILABLE,
        ERROR
    }

    private errordomain UpdateError {
        IN_PROGRESS // Update is already in progress
    }

    /**
     * This class lets the user of this library perform
     * an update of the used rule-files.
     */
    public class Updater : GLib.Object {
        /**
         * Constants
         */
        private static  string UPDATE_DIR = Path.build_filename(Environment.get_user_data_dir(),
                                                              "libhttpseverywhere");
        private static const string UPDATE_URL = "https://www.eff.org/files/https-everywhere-latest.xpi";
        private static const string LOCK_NAME = "lock";

        /**
         * Used to check whether we are already doing an update
         */
        private bool update_in_progress = false;
        private UpdateState _update_state = UpdateState.FINISHED;

        /**
         * Represents the currently processed state of the update
         * process. When no update is running, this property is of no use.
         */
        public UpdateState update_state {
            public get {return this._update_state;}
            private set {this._update_state = value;}
        }

        /**
         * Writes a file to the disk that inhibits other instances
         * of this library from doing updates
         */
        private void lock_update() throws UpdateError {
            try {
                string o;
                FileUtils.get_contents(Path.build_filename(UPDATE_DIR, LOCK_NAME), out o);
            } catch (FileError e) {
                try {
                    FileUtils.set_contents(Path.build_filename(UPDATE_DIR, LOCK_NAME), "");
                } catch (FileError e) {
                    error("Could not acquire lock at '%s'",Path.build_filename(UPDATE_DIR, LOCK_NAME));
                }
                update_in_progress = true;
                return;
            }
            throw new UpdateError.IN_PROGRESS("Update is already in progress");
        }

        /**
         * Removes the update lock
         */
        private void unlock_update() {
            FileUtils.unlink(Path.build_filename(UPDATE_DIR, LOCK_NAME));
            update_in_progress = false;
        }

        /**
         * Actually executes the update
         */
        private UpdateResult execute_update() {
            var session = new Soup.Session();


            // Download the XPI package
            update_state = UpdateState.DOWNLOADING_XPI;
            var msg = new Soup.Message("GET", UPDATE_URL);
            InputStream stream = null;
            try {
                stream = session.send(msg, null);
            } catch (Error e) {
                warning("Could not fetch update from '%s'", UPDATE_URL);
                return UpdateResult.ERROR;
            }
            // We expect the packed archive to be ~5 MiB big
            uint8[] output = new uint8[(5*1024*1024)];
            size_t size_read;
            try {
                stream.read_all(output, out size_read, null );
            } catch (IOError e) {
                warning("Could not read HTTP body");
                return UpdateResult.ERROR;
            }

            // Decompressing the XPI package
            update_state = UpdateState.DECOMPRESSING_XPI;

            Archive.Read zipreader = new Archive.Read();
            zipreader.set_format(Archive.Format.ZIP);
            zipreader.open_memory(output, size_read);

            string json = "";
            unowned Archive.Entry e = null;
            while (zipreader.next_header(out e) == Archive.Result.OK) {
                if (e != null && e.pathname() == "chrome/content/rulesets.json") {
                    uint8[] jsonblock = new uint8[1024*1024];
                    while (true) {
                        var r = zipreader.read_data(jsonblock, 1024*1024);
                        if (r < 0) {
                            warning("Failed reading archive stream");
                            return UpdateResult.ERROR;
                        }
                        if (r < 1024*1024 && r != 0) {
                            uint8[] remainder = new uint8[r];
                            Memory.copy(remainder, jsonblock, r);
                            json += (string)remainder;
                            break;
                        }
                        json += (string)jsonblock;
                    }
                    break; // we dont need to read more files if we have the rulesets
                } else
                    zipreader.read_data_skip();
            }

            // Copying the new Rules-File to the target
            update_state = UpdateState.COPYING_RULES;
            string rulesets_path = Path.build_filename(UPDATE_DIR, rulesets_file);
            try {
                FileUtils.set_contents(rulesets_path, json);
            } catch (FileError e) {
                warning("Could not write rulesets file at '%s'", rulesets_path);
                return UpdateResult.ERROR;
            }

            update_state = UpdateState.FINISHED;

            return UpdateResult.SUCCESS;
        } 

        /**
         * This function initializes an update of the used rulefiles
         *
         * It will return true on success and false on failure
         * Remember to reread the rules via {@link HTTPSEverywhere.init}
         */
        public async UpdateResult update() {
            try {
                lock_update();
            } catch (UpdateError e) {
                warning("Cannot start update: Update already in progress");
                return UpdateResult.ERROR;
            }

            var result = execute_update();
            unlock_update();
            return result;
        }
    }
}
