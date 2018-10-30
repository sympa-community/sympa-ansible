<?php
/**
 * RENATER's MOTD
 * @author Etienne MELEARD <etienne.meleard@renater.fr>
 * @date 2018-09-19
 */

/**
 * Plugin
 */
class action_plugin_motd extends DokuWiki_Action_Plugin {
    /**
     * Register listeners
     * 
     * @param Doku_Event_Handler $controller
     */
    public function register(Doku_Event_Handler $controller) {
        $controller->register_hook('TPL_METAHEADER_OUTPUT', 'BEFORE', $this, 'handle');
    }
    
    /**
     * Handle event
     * 
     * @param Doku_Event $event
     * @param mixed $param
     */
    public function handle(Doku_Event $event, $param) {
        global $conf;
        $url = $conf['plugin']['motd']['url'];
        
        $event->data['link'][] = ['type' => 'text/css', 'rel' => 'stylesheet', 'href' => DOKU_BASE.'lib/plugins/motd/motd.css'];
        $event->data['script'][] = ['type' => 'text/javascript', 'src' => DOKU_BASE.'lib/plugins/motd/motd.js'];
        $event->data['script'][] = ['type' => 'text/javascript', '_data' => "jQuery(function(){window.motd.load('$url', 'dokuwiki');})"];
    }
}
