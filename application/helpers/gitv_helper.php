<?php defined('BASEPATH') OR exit('No direct script access allowed');

class ApplicationVersion
{
    const MAJOR = 1;
    const MINOR = 5;
    const PATCH = 4;

    public static function get()
    {
        $hash = exec("git rev-list --tags --max-count=1");
        return exec("git describe --tags $hash"); 
    }
}


?>