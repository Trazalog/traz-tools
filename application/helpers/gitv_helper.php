<?php defined('BASEPATH') OR exit('No direct script access allowed');

class ApplicationVersion
{
    const MAJOR = 1;
    const MINOR = 5;
    const PATCH = 4;

    public static function getVerision() {

        $hash = exec("git rev-list --tags --max-count=1");
        return exec("git describe --tags $hash"); 
    }

    public static function getLastVersions() {

        $tagsArray = explode(PHP_EOL, shell_exec('git log --tags --simplify-by-decoration --pretty="format:%ci %d"'));

        return json_encode($tagsArray);
        
        
    }
}


?>