package org.wso2.carbon.connector;
/*
*  Copyright (c) 2017, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
*
*  WSO2 Inc. licenses this file to you under the Apache License,
*  Version 2.0 (the "License"); you may not use this file except
*  in compliance with the License.
*  You may obtain a copy of the License at
*
*    http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing,
* software distributed under the License is distributed on an
* "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
* KIND, either express or implied.  See the License for the
* specific language governing permissions and limitations
* under the License.
*/

import com.fazecast.jSerialComm.*; 
import org.apache.commons.logging.Log;
import org.apache.synapse.MessageContext;
import org.wso2.carbon.connector.core.AbstractConnector;
import org.wso2.carbon.connector.core.ConnectException;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.Enumeration;

/**
 * Sample method implementation.
 */
public class BasculaConnector extends AbstractConnector {

	private Log log;
	private SerialPort port = null;


	/**
	 * Abre una instancia unica de puerto para recibir el peso
	 * @param mc Message Context de WSO2
	 * @throws ConnectException
	 */
	public void openPort(MessageContext mc) throws Exception {
	try{
			String portName = (String) getParameter(mc, "portname");
			String bauds = (String) getParameter(mc, "bauds");
			String databits = (String) getParameter(mc, "databits");
			String stopbits = (String) getParameter(mc, "stopbits");
			String parity = (String) getParameter(mc, "parity");

			try{

				log.info("BASCCONN: Puerto solicitado: " + portName + "(bauds " + bauds + " databits " + databits + " stopbits " +stopbits + " parity "+parity +")");
				port = SerialPort.getCommPort(portName);
			} catch ( SerialPortInvalidPortException sie)
			{
				log.info("BASCCONN: Puerto inválido: " + portName + ": " + sie.getMessage());
				throw sie;	
			}

			port.setComPortTimeouts(SerialPort.TIMEOUT_READ_BLOCKING, 1000, 0);

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
	 * Abre un InputStream esperando la trama que la báscula envia por el puerto en serie portName
	 * @param mc wso2 message conext
	 */
	@Override
	public void connect(MessageContext mc) throws ConnectException {
		try {
			log = mc.getServiceLog();
			BufferedReader is;
			
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
				is = new BufferedReader(new InputStreamReader(port.getInputStream()));

				// obtengo el string recibido con el peso y lo seteo en la propiedad de wso2

				String trama = "";
				if (is != null) {
					log.info("BASCCONN: readLine()");
					trama = is.readLine();
					log.info("BASCCONN: peso leido" + trama);					
					mc.setProperty("pesoBascula", trama);
					log.info("BASCCONN: pesoBascula seteada" + trama);					
					
				}

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

