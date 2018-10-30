/** MOTD handler - RENATER **/
window.motd = {
    /** NOW */
    now: Math.floor((new Date()).getTime() / 1000),
    
    /** UI */
    container: undefined,
    
    /** Popup classes */
    classes: 'reveal',
    
    /** Translations **/
    dictionnary: {
        close: {en: 'close', fr: 'fermer'},
        i_got_it: {en: 'I got it', fr: 'J\'ai compris'},
    },
    
    /** Hidden motd storage */
    hidden: {
        /** key in global storage */
        storage_key: 'user_hide_motd',
        
        /** Cache keys prefix */
        prefix: 'motd_',
        
        /** cache */
        cache: undefined,
        
        /**
         * Get cache key for id
         * 
         * @param int id
         * 
         * @return string
         */
        getKey: function(id) {
            return this.prefix + id;
        },
        
        /**
         * Get cached data
         * 
         * @param int id
         * 
         * @return object
         */
        get: function(id) {
            if(!this.cache) {
                var c = window.localStorage.getItem(this.storage_key);
                this.cache = c ? JSON.parse(c) : {};
            }
            
            var k = this.getKey(id);
            
            return (k in this.cache) ? this.cache[k] : null;
        },
        
        /**
         * Set cached data
         * 
         * @param int id
         * @param mixed data
         */
        set: function(id, data) {
            if(!this.cache) this.get(id);
            
            var k = this.getKey(id);
            if(data) {
                this.cache[k] = data;
                
            } else if(k in this.cache) {
                delete this.cache[k];
            }
            
            window.localStorage.setItem(this.storage_key, JSON.stringify(this.cache));
        },
        
        /**
         * Clean cache
         * 
         * @param callable filter gets id and data, returns bool telling if should keep
         */
        clean: function(filter) {
            this.get('dummy'); // Loads cache if not already loaded
            
            for(var k in this.cache)
                if(!filter.call(this, parseInt(k.substr(this.prefix.length)), this.cache[k]))
                    delete this.cache[k];
            
            this.set('dummy', null); // Saves
        },
    },
    
    /**
     * Get lang code
     * 
     * @return string
     */
    getLang: function() {
        var l = jQuery('html').attr('lang');
        return l ? l.split(/-/).shift() : 'fr';
    },
    
    /**
     * Translate
     * 
     * @param string key
     * 
     * @return string
     */
    translate: function(key) {
        var c = this.getLang();
        
        return (this.dictionnary[key] && this.dictionnary[key][c]) ? this.dictionnary[key][c] : '{' + key + '}';
    },
    
    /**
     * Check if hidden
     * 
     * @param int id
     * 
     * @return bool
     */
    isHidden: function(id, lastup) {
        var m = this.hidden.get(id);
        return m && m.lastup && (m.lastup >= lastup);
    },
    
    /**
     * Hide
     * 
     * @param int id
     */
    hide: function(id) {
        this.hidden.set(id, {lastup: this.now});
    },
    
    /**
     * Disable hiding (for msg update)
     * 
     * @param int id
     */
    unHide: function(id) {
        this.hidden.set(id, null);
    },
    
    /**
     * Popup modal and gives ui handle
     * 
     * @return jQuery
     */
    popup: function() {
        if(!this.container) {
            var reveal = jQuery('<div class="' + this.classes + '" id="motd-modal" data-reveal data-count="0" />').hide().appendTo('body');
            var close = function() {
                if(!reveal.hasClass('diy')) return;
                
                reveal.data('bg').hide();
                reveal.hide();
            };
            
            jQuery('<button class="close-button" data-close type="button" />')
                .attr({'aria-label': this.translate('close')})
                .append(jQuery('<span aria-hidden="true" />').html('&times;'))
                .appendTo(reveal)
                .on('click', close);
            
            this.container = jQuery('<article />').appendTo(reveal);
            
            var handler = this;
            jQuery('<button data-close data-context="close_modal" class="button"/>')
                .attr({'aria-label': this.translate('close')})
                .text(this.translate('i_got_it'))
                .appendTo(reveal)
                .on('click', function() {
                    // Flag displayed motds
                    jQuery('#motd-modal').find('[data-motd-id]').each(function() {
                        handler.hide(parseInt(jQuery(this).attr('data-motd-id')));
                    });
                    
                    close();
                });
            
            if('Foundation' in window) {
                (new Foundation.Reveal(reveal)).open();
                
            } else {
                var bg = jQuery('<div class="diy reveal-modal-bg" />').appendTo('body').on('click', close);
                reveal.data('bg', bg);
                reveal.addClass('diy').show();
            }
        }
        
        return this.container;
    },
    
    /**
     * Display single
     * 
     * @param object motd
     */
    display: function(motd) {
        var p = this.popup();
        
        var ctn = jQuery('<article />').attr({
            'data-motd-id': motd.id,
            'data-motd-last_update_time': motd.last_update_time ? motd.last_update_time.raw : motd.creation_time.raw,
            'data-start-diffusion-time': motd.start_diffusion_time.raw,
            'data-end-diffusion-time': motd.end_diffusion_time.raw,
            'data-time-zone': motd.time_zone,
        }).appendTo(p);
        
        var r = jQuery('#motd-modal');
        r.attr({'data-count': parseInt(r.attr('data-count')) + 1});
        
        ctn.append(jQuery('<h1 />').html('&ldquo; ' + motd.title + ' &rdquo;'));
        
        var translations = {};
        for(var i in motd.content)
            translations[motd.content[i].lang] = motd.content[i].content;
        
        var lang = this.getLang();
        var msg = (lang in translations) ? translations[lang] : translations.fr;
        
        if(msg)
            ctn.append(msg);
        
        // Relocate popup
        r.css({
            top: (jQuery(window).height() - r.height())/2 + 'px'
        });
    },
    
    /**
     * Wrap caller
     * 
     * @param callable handler
     * 
     * @return callable
     */
    wrap: function(handler) {
        var call = {ctx: this, func: handler};
        return function() {
            call.func.apply(call.ctx, arguments);
        };
    },
    
    /**
     * Load motds
     * 
     * @param string url
     * @param string classes
     */
    load: function(url, classes) {
        if(classes) this.classes += ' ' + classes;
        
        jQuery.getJSON(url, this.wrap(function(motds) {
            var known = [];
            for(var i=0; i<motds.length; i++) {
                var motd = motds[i];
                
                if(motd.start_diffusion_time.raw > this.now) continue;
                if(motd.end_diffusion_time.raw < this.now) continue;
                
                known.push(motd.id);
                
                var lastup = motd.last_update_time ? motd.last_update_time.raw : motd.creation_time.raw;
                if(this.isHidden(motd.id, lastup)) continue;
                
                this.display(motd);
            }
            
            // Clean unknown / out of bounds
            this.hidden.clean(function(id, data) {
                return known.indexOf(id) >= 0;
            });
            
        })).fail(function(error) {
            console.log(error);
        });
    },
};
