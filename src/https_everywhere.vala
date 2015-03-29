namespace HTTPSEverywhere {
    private bool initialized = false;

    /**
     * This function initializes HTTPSEverywhere by loading
     * the rulesets from the filesystem.
     */
    public void init() {
        initialized = true;
        parse_rulesets();
    }

    /**
     * Takes an URL and returns the appropriate
     * HTTPS-enabled counterpart if there is any
     */
    public string httpsify(string url) {
        if (!initialized){
            critical("HTTPSEverywhere was not initialized");
            return url;
        }
        return "";
    }

    /**
     * Returns true when there is a #Ruleset for the
     * given URL
     */
    public bool has_https(string url) {
        if (!initialized){
            critical("HTTPSEverywhere was not initialized");
            return false;
        }
        return false;
    }

    /**
     * Parses all rulesets that can be found in the system
     */
    private void parse_rulesets() { 
    }

    /**
     * Returns only the host-part of @url 
     */
    private string extract_host(string url) {
        return "";
    }

    /**
     *
     */
}
