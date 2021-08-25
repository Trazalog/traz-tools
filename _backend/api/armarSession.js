function armarSession(mc) {
try{       
   var log = mc.getServiceLog(); 
   //Tomo la cookie de sesion de bonita
   var cuki = mc.getProperty("bonitaCookies"); 
   log.debug("cuki recibida:"+cuki);   
                   
   //parseo los parametros
   var xbo = cuki.match(/X-Bonita-API-Token=(?!\;)(.+?);/g);
   log.debug("xbo:" + xbo[0]);
		   
   //armo primero el header de X-Bonita-API-Token
   var xbonitaapi = xbo.toString().substr(19);
   log.debug("x-bonita-api-token:" + xbonitaapi.slice(0,-1));
		   
    mc.setProperty('bonitaApiToken',xbonitaapi.slice(0,-1));
		   
    //obtengo el header de session y de bonita.tenant		   
    var jsession = cuki.match(/JSESSIONID=(?!\;)(.+?);/g);
    log.debug("jsessionid:" + jsession[0]);

    var btenant = cuki.match(/bonita.tenant=(?!\;)(.+?);/g);
    log.debug("btenant" + btenant[0]);
		   
    //armo la cookie
    var newcuk = xbo[0]+jsession[0]+btenant[0];
    log.debug('bonitaCookies cuk:'+newcuk);
    mc.setProperty('bonitaCookies',newcuk);
		   
    //usare ambas propiesdades luego para armar headers y cookies
    return true;
   }
   catch(error1)
   {  
       log.error("armarSession - ERROR :" + error1);
   }
}

