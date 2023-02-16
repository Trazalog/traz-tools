package org.wso2.carbon.connector;

import com.fazecast.jSerialComm.*; 
import org.apache.commons.logging.Log;
import org.apache.synapse.MessageContext;
import org.wso2.carbon.connector.core.AbstractConnector;
import org.wso2.carbon.connector.core.ConnectException;

import java.io.InputStream;
import java.io.IOException;
import java.util.Enumeration;


/* Conector para leer el peso de una báscula vía port serial COM
 * @author rruiz - TZL
*/
public class BasculaConnector extends AbstractConnector {

	private Log log;
	private SerialPort port = null;
	String portName;
	String bauds;
	String databits;
	String stopbits;
	String parity;

	/**
	 * Abre una instancia unica de puerto para recibir el peso
	 * @param mc Message Context de WSO2
	 * @throws ConnectException
	 */
	public void openPort(MessageContext mc) throws Exception {
	try{
			portName = (String) getParameter(mc, "portname");
			bauds = (String) getParameter(mc, "bauds");
			databits = (String) getParameter(mc, "databits");
			stopbits = (String) getParameter(mc, "stopbits");
			parity = (String) getParameter(mc, "parity");

			try{

				log.info("BASCCONN: Puerto solicitado: " + portName + "(bauds " + bauds + " databits " + databits + " stopbits " +stopbits + " parity "+parity +")");
				port = SerialPort.getCommPort(portName);
			} catch ( SerialPortInvalidPortException sie)
			{
				log.info("BASCCONN: Puerto inválido: " + portName + ": " + sie.getMessage());
				throw sie;	
			}

			port.setComPortTimeouts(SerialPort.TIMEOUT_READ_BLOCKING, 0, 0);

			log.info("BASCCONN: abriendo puerto "+portName);
			if (port.openPort()){
				log.info("BASCCONN: seteando parametros a puerto");
				port.setBaudRate(Integer.parseInt(bauds));
				port.setNumDataBits(Integer.parseInt(databits));
				port.setNumStopBits(Integer.parseInt(stopbits));
				port.setParity(Integer.parseInt(parity));
			} else { 
				log.info("BASCCONN: openport dio false");
			} 

		} catch (Exception e){
			log.info("BASCCONN: Error fatal abriendo puerto: " +  e.getMessage());
			throw e;
		}
	}

	/**
	 * Abre un InputStream esperando la trama que la báscula envia por el puerto en serie portName, lee solo la cantidad de databits
	 * @param mc wso2 message conext
	 */
	@Override
	public void connect(MessageContext mc) throws ConnectException {
		InputStream is;
		try {
			log = mc.getServiceLog();
			
			log.info("BASCCONN: connect");
			//Si es la primer vez que nos conectamos, crea la conexión para el puerto
			if (port == null) {
				try {
					log.debug("BASCCONN: puerto cerrado, abriendo");
					openPort(mc);
				} catch (Exception e) {
					log.info("BASCCONN: Error abriendo puertos");
					throw e;
				}
			}

			try {
				//Leo el peso de la bascula
				log.info("BASCCONN: leyendo peso");
				is= port.getInputStream();
				log.info("BASCCONN: leyendo peso");

				String trama = "";
								//br = new BufferedReader(new InputStreamReader(port.getInputStream()));
				char c; 
				for (int cant=0 ; cant<Integer.parseInt(databits) ; cant++){
					c = (char) is.read(); 
					log.info("BASCCONN: c "+c);
					trama += c + ""; 
				}

				log.info("BASCCONN: peso leido" + trama);					
				mc.setProperty("pesoBascula", trama);
				log.info("BASCCONN: Set property a mc, pesoBascula" + " = " + trama);
			} catch (SerialPortTimeoutException spte) {
				log.info("BASCCONN: tmout ");
				throw spte;
			} catch (Exception e) {
				log.info("BASCCONN: Error recibiendo peso "+e.getMessage());
				throw e;
			}

			// Finalizo la lectura
			try {
				log.info("BASCCONN: cierro lectura");
				//br.close();
				is.close();
				log.info("BASCCONN: cerrado");
			} catch (Exception e) {
				log.info("BASCCONN: Error cerrando inputStream ");
				throw e;
			}
		} catch (SerialPortTimeoutException spte) {
			log.info("BASCCONN: Dio timeout " + spte.getMessage());
		} catch (Exception e) {
			log.info("BASCCONN: Imposible tomar peso" + e.getMessage());
			log.info(e);
			throw new ConnectException(e);
		}

	}
}

