<?php
/**
 * RENATER's MOTD injection
 *
 * @author Etienne MELEARD <etienne.meleard@renater.fr>
 * @date 2018-06-29
 */

/**
 * Plugin
 */
class motdPlugin extends \LimeSurvey\PluginManager\PluginBase {
    /** @var string **/
    protected $storage = 'DbStorage';
    
    /** @var string **/
    static protected $description = 'Injects MOTD';
    
    /** @var string **/
    static protected $name = 'motdPlugin';
    
    /** @var array */
    protected $settings = [
        'url' => [
            'type' => 'string',
            'label' => 'Url to get MOTDs from',
            'default' => ''
        ],
    ];
    
    /** @var \AdminController **/
    private $controller = null;
    
    /**
     * Initialize plugin
     */
    public function init() {
        $url = $this->get('url');
        $js = "jQuery(function(){window.motd.load('$url', 'limesurvey');});";
        
        $assets = Yii::app()->assetManager->publish(dirname(__FILE__).'/assets/');
        Yii::app()->clientScript->registerScriptFile($assets.'/motd.js');
        Yii::app()->clientScript->registerCssFile($assets.'/motd.css');
        Yii::app()->clientScript->registerScript('motd-loader', $js, LSYii_ClientScript::POS_HEAD);
    }
}
