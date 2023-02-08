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

import gnu.io.*;
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

		String portName = (String) getParameter(mc, "portname");
		String bauds = (String) getParameter(mc, "bauds");
		String databits = (String) getParameter(mc, "databits");
		String stopbits = (String) getParameter(mc, "stopbits");
		String parity = (String) getParameter(mc, "parity");

		log.info("BASCCONN: Abriendo puerto serie " + portName);

		System.setProperty("gnu.io.rxtx.SerialPorts", portName);
		Enumeration portIdentifiers = CommPortIdentifier.getPortIdentifiers();

		CommPortIdentifier portId = null;  // will be set if port found
		while (portIdentifiers.hasMoreElements()) {
			CommPortIdentifier pid = (CommPortIdentifier) portIdentifiers.nextElement();

			log.info("BASCCONN: Leyendo port " + pid.toString());
			if (pid.getPortType() == CommPortIdentifier.PORT_SERIAL &&
					pid.getName().equals(portName)) {
				log.info("BASCCONN: el puerto seleccionado es " + pid.getName());
				portId = pid;
				break;
			}
		}
		if (portId == null) {
			log.error("BASCCONN: Error intentando abrir puerto " + portName);
			throw new NoSuchPortException();

		}

		// Use port identifier for acquiring the port
		try {
			port = (SerialPort) portId.open(
					"trazalogtools", // Name of the application asking for the port
					10000   // Wait max. 10 sec. to acquire port
			);
		} catch (PortInUseException e) {
			log.error("BASCCONN: Puerto ya en uso: " + e);
			throw e;
		}

		// Now we are granted exclusive access to the particular serial
		// port. We can configure it and obtain input and output streams.
		//
		try {
			port.setSerialPortParams(
					bauds,
					databits,
					stopbits,
					parity);

		} catch (UnsupportedCommOperationException e) {
			log.error("BASCCONN: Error configurando puerto: " + portName + ": " + e);
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

			//Si es la primer vez que nos conectamos, crea la conexión para el puerto
			if (port == null) {
				try {
					openPort(mc);
				} catch (Exception e) {
					log.error("BASCCONN: Error abriendo puertos");
					throw e;
				}
			}

			//Leo el peso de la bascula
			try {
				is = new BufferedReader(new InputStreamReader(port.getInputStream()));
			} catch (IOException e) {
				log.error("BASCCONN: No se puede abrir el input stream: solo escritura");
				is = null;
			}

			// obtengo el string recibido con el peso y lo seteo en la propiedad de wso2
			try {
				String trama = "";
				if (is != null) {
					trama = is.readLine();
					mc.setProperty("pesoBascula", trama);
				}

				log.info("BASCCONN: Set property a mc, pesoBascula" + " = " + trama);
			} catch (Exception e) {
				log.error("BASCCONN: Error recibiendo peso "+e.getMessage());
				throw e;
			}

			// Finalizo la lectura
				try {
					is.close();
				} catch (Exception e) {
					log.error("BASCCONN: Error cerrando inputStream ");
					throw e;
				}
		} catch (Exception e) {
			log.error("BASCCONN: Imposible tomar peso",e);
			log.error(e);
			throw new ConnectException(e);
		}

	}
}

