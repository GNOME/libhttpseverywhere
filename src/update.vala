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

    private errordomain UpdateError {IN_PROGRESS}

    /**
     * This class lets the user of this library perform
     * an update of the used rule-files.
     */
    class Updater : GLib.Object {
        /**
         * Used to check whether we are already doing an update
         */
        private bool update_in_progress = false;
        private UpdateState _update_state = UpdateState.FINISHED;
        private uint _update_percentage = 100;

        /**
         * Represents the currently processed state of the update
         * process. When no update is running, this property is of no use.
         */
        public UpdateState update_state {
            public get {return this._update_state;}
            private set {this._update_state = value;}
        }

        /**
         * Represents the estimated progress of the update in percent.
         * When no update is running, this property is of no use.
         */
        public uint update_percentage {
            public get {return this._update_percentage;}
            private set {this._update_percentage = value;}
        }
        
        /**
         * Writes a file to the disk that inhibits other instances
         * of this library from doing updates
         */
        private void lock_update() throws UpdateError {
            // TODO: write file
            update_in_progress = true;
        }

        /**
         * Removes the update lock
         */
        private void unlock_update() {
            // TODO: delete file
            update_in_progress = false; 
        }

        /**
         * This function initializes an update of the used rulefiles
         * It will return true on success and false on failure
         */
        public async UpdateResult update() {
            try {
                lock_update();
            } catch (UpdateError e) {
                warning("Cannot start update: Update already in progress");
            }
            
            // Get RDF data
            update_state = UpdateState.LOADING_RDF;
            //TODO: implement

            // Download the XPI package
            update_state = UpdateState.DOWNLOADING_XPI;
            // TODO: implement

            // Decompressing the XPI package
            update_state = UpdateState.DECOMPRESSING_XPI;
            // TODO: implement

            // Copying the new Rules-SQLite-DB
            update_state = UpdateState.COPYING_RULES;
            // TODO: implement
            
            update_state = UpdateState.FINISHED;    
            unlock_update();

            return UpdateResult.SUCCESS;
        }
    }
}
