package org.wso2.carbon.connector;

import java.io.InputStream; 

import org.apache.commons.logging.Log;
import org.apache.synapse.MessageContext;
import org.wso2.carbon.connector.core.AbstractConnector;
import org.wso2.carbon.connector.core.ConnectException;

import com.fazecast.jSerialComm.SerialPort;
import com.fazecast.jSerialComm.SerialPortInvalidPortException;
import com.fazecast.jSerialComm.SerialPortTimeoutException;


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

			// Configurar timeout: TIMEOUT_READ_SEMI_BLOCKING con timeout de 1000ms
			// Esto permite leer datos disponibles sin bloquear indefinidamente
			port.setComPortTimeouts(SerialPort.TIMEOUT_READ_SEMI_BLOCKING, 1000, 0);

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
		InputStream is = null;
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
				is = port.getInputStream();
				
				// CRÍTICO: Limpiar el buffer antes de leer para evitar datos antiguos
				// Descarta todos los bytes disponibles en el buffer para leer solo datos frescos
				int availableBytes = is.available();
				if (availableBytes > 0) {
					log.info("BASCCONN: Limpiando buffer - descartando " + availableBytes + " bytes antiguos");
					// Leer y descartar todos los bytes antiguos del buffer
					byte[] buffer = new byte[availableBytes];
					is.read(buffer, 0, availableBytes);
					log.info("BASCCONN: Buffer limpiado, esperando datos frescos");
				}
				
				// Pequeña pausa para asegurar que lleguen datos frescos de la báscula
				Thread.sleep(50);
				
				// Verificar que hay datos disponibles después de limpiar
				int newAvailableBytes = is.available();
				if (newAvailableBytes == 0) {
					log.warn("BASCCONN: No hay datos disponibles después de limpiar buffer");
					// Esperar un poco más para recibir datos
					Thread.sleep(100);
					newAvailableBytes = is.available();
				}
				
				if (newAvailableBytes == 0) {
					log.warn("BASCCONN: Aún no hay datos disponibles, puede que la báscula no esté enviando");
					mc.setProperty("pesoBascula", "");
					return;
				}
				
				log.info("BASCCONN: Leyendo " + newAvailableBytes + " bytes disponibles");
				
				// Leer solo la cantidad de databits especificada
				int bytesToRead = Integer.parseInt(databits);
				String trama = "";
				char c; 
				for (int cant = 0; cant < bytesToRead && cant < newAvailableBytes; cant++){
					c = (char) is.read(); 
					log.debug("BASCCONN: c[" + cant + "]=" + c);
					trama += c; 
				}
				
				// Si no se leyeron suficientes bytes, completar con lo que haya
				if (trama.length() < bytesToRead) {
					log.warn("BASCCONN: Solo se leyeron " + trama.length() + " de " + bytesToRead + " bytes esperados");
				}

				log.info("BASCCONN: peso leido: " + trama);					
				mc.setProperty("pesoBascula", trama);
				log.info("BASCCONN: Set property a mc, pesoBascula = " + trama);
			} catch (SerialPortTimeoutException spte) {
				log.info("BASCCONN: timeout en lectura");
				throw spte;
			} catch (InterruptedException ie) {
				log.info("BASCCONN: Interrupción durante espera");
				Thread.currentThread().interrupt();
				throw new ConnectException(ie);
			} catch (Exception e) {
				log.info("BASCCONN: Error recibiendo peso: " + e.getMessage());
				throw e;
			} finally {
				// No cerramos el InputStream aquí para mantener el puerto abierto
				// El puerto se mantiene abierto para lecturas posteriores
				if (is != null) {
					// No cerramos el stream, solo lo dejamos disponible
					log.debug("BASCCONN: Lectura completada, manteniendo stream abierto");
				}
			}
		} catch (SerialPortTimeoutException spte) {
			log.info("BASCCONN: Dio timeout " + spte.getMessage());
			mc.setProperty("pesoBascula", "");
		} catch (Exception e) {
			log.info("BASCCONN: Imposible tomar peso: " + e.getMessage());
			log.error("BASCCONN: Error completo", e);
			mc.setProperty("pesoBascula", "");
			throw new ConnectException(e);
		}

	}
}

