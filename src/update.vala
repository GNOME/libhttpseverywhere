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

namespace HTTPSEverywhere {
    /**
     * This enumerates states the update passes
     * through. They can be obtained via {@link Updater.update_state}
     * And used to show informative messages about progress
     * to the user.
     */
    public enum UpdateState {
        FINISHED,
        CHECKING_AVAILABILITY,
        DOWNLOADING_XPI,
        DECOMPRESSING_XPI,
        COPYING_RULES
    }

    /**
     * Errors that may occur during an update process
     */
    public errordomain UpdateError {
        IN_PROGRESS, // Update is already in progress
        NO_UPDATE_AVAILABLE,
        CANT_REACH_SERVER,
        CANT_READ_HTTP_BODY,
        CANT_READ_FROM_ARCHIVE,
        NO_RULESET_FILE,
        WRITE_FAILED
    }

    /**
     * This class lets the user of this library perform
     * an update of the used rule-files.
     */
    public class Updater : GLib.Object {
        /**
         * Constants
         */
        private static string UPDATE_DIR = Path.build_filename(Environment.get_user_data_dir(),
                                                               "libhttpseverywhere");
        private const string UPDATE_URL = "https://www.eff.org/files/https-everywhere-latest.xpi";
        private const string RULESET_PATH = "rules/default.rulesets";
        private const string LOCK_NAME = "lock";
        private const string ETAG_NAME = "etag";

        /**
         * Used to check whether we are already doing an update
         */
        private bool update_in_progress = false;
        private UpdateState _update_state = UpdateState.FINISHED;

        private Context context;

        /**
         * Represents the currently processed state of the update
         * process. When no update is running, this property is of no use.
         */
        public UpdateState update_state {
            public get {return this._update_state;}
            private set {this._update_state = value;}
        }

        /**
         * Create a new Updater for the given library context.
         */
        public Updater(Context context) {
            this.context = context;
        }

        /**
         * Writes a file to the disk that inhibits other instances
         * of this library from doing updates
         *
         * If the lockfile has been created longer than 20 minutes
         * ago, the program will assume that it is a file from a failed
         * attempt to update and continue anyway.
         * 40 Minutes is the approximate time a user of a 56k-model will
         * need to download the updates.
         */
        private void lock_update() throws UpdateError {
            var file = File.new_for_path(Path.build_filename(UPDATE_DIR, LOCK_NAME));
            if (file.query_exists()) {
                try {
                    var info = file.query_info("*", FileQueryInfoFlags.NONE);
                    DateTime modification_time = new GLib.DateTime.from_timeval_local(info.get_modification_time());
                    DateTime current_time = new GLib.DateTime.now_local();
                    if (current_time.difference(modification_time) < 40 * TimeSpan.MINUTE) {
                        throw new UpdateError.IN_PROGRESS("Update is already in progress");
                    }
                    update_in_progress = true;
                } catch (Error e ) {
                    if (e is UpdateError.IN_PROGRESS) {
                        throw (UpdateError)e;
                    }
                    throw new UpdateError.WRITE_FAILED("Error querying lock file: %s".printf(e.message));
                }
            } else {
                try {
                    file.create(FileCreateFlags.NONE);
                    update_in_progress = true;
                } catch (Error e) {
                    throw new UpdateError.WRITE_FAILED("Error creating lock file: %s".printf(e.message));
                }
            }
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
        private async void execute_update(Cancellable? cancellable = null) throws UpdateError, IOError {
            var session = new Soup.Session();

            // Check if update is necessary
            update_state = UpdateState.CHECKING_AVAILABILITY;
            try {
                string etag;
                FileUtils.get_contents(Path.build_filename(UPDATE_DIR, ETAG_NAME), out etag);
                var msg = new Soup.Message("HEAD", UPDATE_URL);
                try {
                    yield session.send_async(msg, cancellable);
                    if (msg.response_headers.get_one("Etag") == etag) {
                        throw new UpdateError.NO_UPDATE_AVAILABLE("Already the freshest version!");
                    }
                } catch (Error e) {
                    if (e is IOError.CANCELLED)
                        throw (IOError) e;
                    if (e is UpdateError.NO_UPDATE_AVAILABLE)
                        throw (UpdateError) e;
                    debug(e.message);
                    throw new UpdateError.CANT_REACH_SERVER("Couldn't request update from '%s'", UPDATE_URL);
                }
            } catch (FileError e) {}

            // Download the XPI package
            update_state = UpdateState.DOWNLOADING_XPI;
            var msg = new Soup.Message("GET", UPDATE_URL);
            InputStream stream = null;
            try {
                stream = yield session.send_async(msg, cancellable);
            } catch (Error e) {
                if (e is IOError.CANCELLED)
                    throw (IOError) e;
                debug(e.message);
                throw new UpdateError.CANT_REACH_SERVER("Couldn't request update from '%s'", UPDATE_URL);
            }
            // We expect the packed archive to be ~5 MiB big
            uint8[] output = new uint8[(5*1024*1024)];
            size_t size_read;
            try {
                yield stream.read_all_async(output, GLib.Priority.DEFAULT, cancellable, out size_read);
            } catch (Error e) {
                if (e is IOError.CANCELLED)
                    throw (IOError) e;
                throw new UpdateError.CANT_READ_HTTP_BODY(e.message);
            }

            // Decompressing the XPI package
            // FIXME: Lots of slow sync operations below here, should be made async.
            update_state = UpdateState.DECOMPRESSING_XPI;

            Archive.Read zipreader = new Archive.Read();
            zipreader.set_format(Archive.Format.ZIP);
#if VALA_0_42
            output.length = (int) size_read;
            zipreader.open_memory(output);
#else
            zipreader.open_memory(output, size_read);
#endif

            string json = "";
            unowned Archive.Entry e = null;
            bool found_ruleset_file = false;
            while (zipreader.next_header(out e) == Archive.Result.OK) {
                if (e != null && e.pathname() == Updater.RULESET_PATH) {
                    found_ruleset_file = true;
                    uint8[] jsonblock = new uint8[1024*1024];
                    while (true) {
#if VALA_0_42
                        var r = zipreader.read_data(jsonblock);
#else
                        var r = zipreader.read_data(jsonblock, jsonblock.length);
#endif
                        if (r < 0) {
                            throw new UpdateError.CANT_READ_FROM_ARCHIVE("Failed reading archive stream");
                        }
                        if (r < jsonblock.length && r != 0) {
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

            // Throw an Exception when the expected ruleset file could not be found
            if (!found_ruleset_file)
                throw new UpdateError.NO_RULESET_FILE("Could not find expected ruleset file in the downloaded archive: %s", Updater.RULESET_PATH);

            // Copying the new Rules-File to the target
            update_state = UpdateState.COPYING_RULES;
            string rulesets_path = Path.build_filename(UPDATE_DIR, rulesets_file);
            try {
                FileUtils.set_contents(rulesets_path, json);
            } catch (FileError e) {
                throw new UpdateError.WRITE_FAILED("Could not write rulesets file at '%s'".printf(rulesets_path));
            }

            // Write Etag of update to disk
            string etag = msg.response_headers.get_one("Etag");
            string etag_path = Path.build_filename(UPDATE_DIR, ETAG_NAME);
            try {
                FileUtils.set_contents(etag_path, etag);
            } catch (FileError e) {
                throw new UpdateError.WRITE_FAILED("Could not write etag file at '%s'".printf(etag_path));
            }

            update_state = UpdateState.FINISHED;
        } 

        /**
         * This function initializes an update of the used rulefiles
         *
         * Remember to update the rulesets afterwards via {@link Context.init}
         * It will return true on success and false on failure
         */
        public async void update(Cancellable? cancellable = null) throws UpdateError, IOError {
            try {
                var f = File.new_for_path(UPDATE_DIR);
                f.make_directory_with_parents();
            } catch (Error e) {
                if (!(e is IOError.EXISTS))
                    critical("Could not create %s: %s", UPDATE_DIR, e.message);
            }

            lock_update();
            try {
                yield execute_update(cancellable);
            } catch (UpdateError e) {
                throw e;
            } finally {
                unlock_update();
            }
        }
    }
}
