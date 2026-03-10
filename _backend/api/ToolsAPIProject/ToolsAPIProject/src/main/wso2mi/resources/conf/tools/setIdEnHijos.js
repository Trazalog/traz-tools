/* Funcion que dados los nombres de un elemento y un arreglo dentro del elemento, agrega a cada item del arreglo la propiedad y valor indicados
   Esto se hace normalmente para impactar datos detalle en una asociacion de datos maestro-detalle, donde precisamos insertar a un determinado id de maestro
   solo soporta una estructura
        "elemento_destino": {
	         "arreglo_destino":{
		                    "atributo1":"valor1",
				    .... (N atributos)
				    "propiedad_destino":"id_padre"
				    }
		}
   Parametros
   Deben setearse en el mc los siguientes parametros
   @setIdEnHijos_elemento_origen: nombre del elemento en el mensaje origen que engloba toda la inforamcion
   @setIdEnHijos_elemento_destino: nombre del elemento en el mensaje destino que engloba toda la inforamcion
   @setIdEnHijos_arreglo_origen: arreglo a recorrer y clonar las propiedades origen 
   @setIdEnHijos_arreglo_destino: arreglo a recorrer para agregar propiedad
   @setIdEnHijos_propiedad_destino: nombre de la propiedad destino
   @setIdEnHijos_id_padre: valor del registro maestro o padre
   @ORIGINAL_PAYLOAD: mensaje recibido por el servicio al invocarse

@author: rruiz
*/
function setIdEnHijos (mc) {
 try{    
		       var log = mc.getServiceLog();         
                       log.info("en setIdEnHijos");
		       // Tomo los nombres de los elementos donde agregaré el id del padre
                       var sourceElement = mc.getProperty("setIdEnHijos_elemento_origen");
                       var targetElement = mc.getProperty("setIdEnHijos_elemento_destino");
                       var sourceArray =   mc.getProperty("setIdEnHijos_arreglo_origen");
                       var targetArray =   mc.getProperty("setIdEnHijos_arreglo_destino");
                       var targetProperty =   mc.getProperty("setIdEnHijos_propiedad_destino");
		       var idPadre = mc.getProperty("setIdEnHijos_id_padre");                     
		       var payloadtmp = mc.getProperty("ORIGINAL_PAYLOAD");              
		       
	               // parseo el mensaje original para armar el nuevo mensaje
		       try{  
		       		var payload = JSON.parse(payloadtmp);              
				
			  }catch(error1)
			  {  
				log.error("setIdEnHijos - ERROR PARSEANDO JSON:" + error1); 
				return false;
                          } 
		       var results =  payload[sourceElement];
		       var response = new Array();          
	               
	               // recorro el arreglo agregando la propiedad y valor destino
		       for (i = 0; i < results[sourceArray].length; ++i)     {               
				log.info("1");
		       		objetoActual = results[sourceArray][i];  
				log.info("2");
			        objetoDestino = new Object();
				for(var k in objetoActual) objetoDestino[k]=objetoActual[k];
				log.info("3");
		       		objetoDestino[targetProperty] = idPadre;                 
				log.info("4");
				response[i] = objetoDestino;          
				}         

	               // Armo el objeto que reemplazará al original y lo seteo como payload en el mc para seguir con la sequence
		       var responsePadre = new Object();          
		       var responseArray = new Object;          
		       responseArray[targetArray] = response;          
		       responsePadre[targetElement] = responseArray ;             
		       mc.setPayloadJSON(responsePadre);
		       return true;

		       }catch(error){   
		        	log.info("setIdEnHijos - ERROR GENERAL AGREGANDO ID:"+error);
                                mc.setProperty("setIdEnHijos","true");  // por si se quiere hacer un switch o un filter con el error 
				
                         	return false;
			}
}





