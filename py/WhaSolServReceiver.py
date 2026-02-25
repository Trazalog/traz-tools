from flask import Flask, request, session
import requests
import os
from twilio.twiml.messaging_response import MessagingResponse
from datetime import datetime,timedelta,timezone
import traceback
import re
import time
import logging
from logging.handlers import RotatingFileHandler
from man_config import Config

SECRET_KEY = 'traztoolsbot2025'
app = Flask(__name__)
app.config.from_object(__name__)
app.logger.setLevel(logging.INFO)
handler = logging.FileHandler(Config.LOG_NAME)
app.logger.addHandler(handler)
    
def obtener_datos_equipo(equi_id):

    try:
        app.logger.info(f"obteniendo datos equ de {equi_id}")
        # Get equipment details from RESTful service
        headers = {'Accept': 'application/json'}

        equi_url = f"{Config.TOOLS_API_URL}/services/MANDataService/equipo/{equi_id}"
        app.logger.info(f"equi url {equi_url}")
        equipment_response = requests.get(equi_url,headers=headers)
        
        if equipment_response.status_code == 200:
            tx =equipment_response.text
            app.logger.info(f"Eq recibido ok {tx}")

            equipo_info = equipment_response.json().get('equipo', {})  # Get the 'equipo' element

            return equipo_info
        else:
            app.logger.info(f" Error http -> {equipment_response.status_code}")
            return
        
    except (Exception) as error:
        app.logger.info(traceback.format_exc())
        app.logger.info("Error al invocar al servicio:", error)
        return None
    
def obtener_datos_usuario(from_number):
    try:
        app.logger.info(f"obteniendo datos usr de {from_number}") 

        headers = {'Accept': 'application/json'}

        # Get equipment details from RESTful service
        wha=from_number.split(':+')[1]
        user_url = f"{Config.TOOLS_API_URL}/services/COREDataService/usuario/porTelefono/{wha}"
        app.logger.info(f"url {user_url}")
        user_response = requests.get(user_url,headers=headers)
        
        if user_response.status_code == 200:
            tx = user_response.text
            app.logger.info(f"Usr recibido ok {tx}")

            user_info = user_response.json().get('usuario', {})  # Get the 'usuario' element

            return  user_info
        else:
            app.logger.info(f" Error http -> {user_response.status_code}")
            return
        
    except (Exception) as error:
        app.logger.info(traceback.format_exc())
        app.logger.info("Error al invocar al servicio:", error)
        return None
    
# converts a given number to emoji      t
def number_to_emoji(num):
    if num == 10:
        return "1️⃣0️⃣"  # Concatenated emojis for 1 and 0
    elif num == 11:
        return "1️⃣1️⃣"  # Concatenated emojis for 1 and 1    
    elif 0 <= num <= 9:
        return f"{num}\uFE0F\u20E3"  # Keycap emoji format for numbers 1 to 9
    else:
        return "Number must be between 0 and 10."

# Helper function to save media (image) to a directory
def save_media(media_url, phone_number):
    # Get the content of the media
    app.logger.info(f"grabando media para {phone_number}")

    media_response = requests.get(media_url,auth=(Config.TWILIO_ACCOUNT_SID, Config.TWILIO_ACCOUNT_TOKEN))
    
    content_type = media_response.headers['Content-Type']
    
    app.logger.info(f"content type {content_type}")
    # remove whatsapp:
    phone_number=phone_number.split(':+')[1]

    if content_type == 'image/jpeg':
        file_name = f"{phone_number}_{int(time.time())}.jpg"
    elif content_type == 'image/png':
        file_name = f"{phone_number}_{int(time.time())}.png"
    elif content_type == 'image/gif':
        file_name = f"{phone_number}_{int(time.time ())}.gif"
    else:
        file_name = f"{phone_number}_{int(time.time())}.xxx"


    # Save the media with the phone number and a timestamp to avoid overwriting files
    file_path = os.path.join(Config.IMAGE_SAVE_DIRECTORY, file_name)

    # Write the media content to a file
    with open(file_path, 'wb') as file:
            file.write(media_response.content)
    
    app.logger.info(f"Media saved to {file_path}")
    return file_name

def create_issue(from_number):
    try:
        app.logger.info("Preparando para crear issue")
        equi_id = session.get('equi_id'+str(from_number), 0)
        datos_equipo = session.get('datos_equipo'+str(from_number), 0)
        datos_usuario = session.get('datos_usuario'+str(from_number), 0)

        if datos_equipo:
            equi_empr_id = datos_equipo['empr_id']
            app.logger.info(f"empr  {equi_empr_id}")
        else:
            return "Id de equipo desconocido"
        
        if datos_usuario:
            user_id = datos_usuario['user_id']
            user_nombre = datos_usuario['nombre']
            user_apellido = datos_usuario['apellido']
            app.logger.info(f"user  {user_id}")
        else:
            return "Id de usuario desconocido"

        current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        falla = session.get('falla'+str(from_number), 0)
        images = session.get('images'+str(from_number), [])
        headers = {'Accept': 'application/json'}
        params = {
            'solicitudServicio': {
                'fec_solicitud': current_time,
                'equi_id': equi_id,
                'estado': 'S',
                'user_id': user_id,
                'solicitante': f'{user_nombre} {user_apellido}',
                'causa': falla,
                'foto': '',
                'empr_id': equi_empr_id,
                'adjuntos': [{'url': 'assets/images/', 'adjunto': '', 'nombre': img} for img in images]
            }
        }
        app.logger.info(f"params son {params}")
        post_url = f"{Config.TOOLS_API_URL}/tools/man/solicitudServicio?bpmSession="
        app.logger.info(f"About to send to {post_url}")
        try:
            issue_response = requests.post(post_url, json=params, headers=headers)
            if issue_response.status_code == 200:
                app.logger.info(f"todo ok recibido {issue_response.text}")
                issue_data = issue_response.json().get('resultado', {})
                issue_id = issue_data['sose_id']
                return f"Su solicitud de servicio número *{issue_id}* fue creada exitósament👷🏽‍♂️👷🏽‍♂️👷🏽‍♂️\n "+\
                                 "Ya estamos trabajando! 🧰🪛⛏️ Puede consultar su avance en https://bit.ly/tzl-tools-man\n\n ¡Muchas gracias! 🙏🏽"
            else:
                app.logger.info(f"Error al crear issue {issue_response.status_code}")
                app.logger.info(f"cuerpo {issue_response.text}")
                return f"Error al crear issue {issue_response.status_code}"
        except requests.exceptions.RequestException as e:
            app.logger.info(traceback.format_exc())
            app.logger.info(f"cuerpo {issue_response.text}")
            return f"Fatal error al crear issue {issue_response.status_code}"
    finally:
        session['step'+str(from_number)] = '0'
        session['equi_id'+str(from_number)] = 0

#la siguiente se dispara desde el global webhook. El tema es que el request.form tiene un formato distinto de que viene desde messaging. Creo que tenemos que usar el 
#de messaging, se adapta mas a nuestro caso de uso
@app.route("/solServWebHook", methods=["POST"])
def webhook():
    try:        
        # Extraer el mensaje entrante y el nÃºmero del remitente
        incoming_msg = request.form.get("Body")
        from_number = request.form.get("From")
        media_url = request.form.get('MediaUrl0')  # The URL for the first media attachment (if any)

        app.logger.info(f"Received message '{incoming_msg}' from {from_number}")

        # Crear una respuesta de Twilio
        resp = MessagingResponse()
        
        step = int(session.get('step'+str(from_number), 0))
        app.logger.info(f"Session step is {step}")

        if step == 0:
            # Validate the format of the incoming message
            match = re.match(Config.WHA_TOOLS_PATTERN, incoming_msg)
    
            if match:
                equi_id = match.group(1)  # Extract the equi_id (which is the integer part)
            else:
                # Send an error message if the format is incorrect
                resp.message("Mensaje incorrecto, por favor reintente")
                session['step'+str(from_number)] = 0
                return str(resp)
            
            session['equi_id'+str(from_number)] = equi_id

            datos_equipo = obtener_datos_equipo(equi_id)  
            session['datos_equipo'+str(from_number)] = datos_equipo

            if datos_equipo:                    
                equi_description = datos_equipo['descripcion']
                equi_codigo = datos_equipo['codigo']
                equi_estado = datos_equipo['estado']    
                equi_empresa = datos_equipo['empresa']   
                equi_marca = datos_equipo['marca']      
                equi_sector = datos_equipo['sector']     
                equi_grupo = datos_equipo['grupo']     
                equi_criticidad = datos_equipo['criticidad']
                equi_area = datos_equipo['area']       
                equi_proceso = datos_equipo['proceso']  
                equi_empr_id = datos_equipo['empr_id']
            else:
                resp.message("Id de equipo desconocido")
                session['step'+str(from_number)] = 0
                return str(resp)
    
            #resp.message(f"Bienvenido a Trazalog Tools Mantenimiento.\n*{equi_description} {equi_codigo}*")
            #return str(resp)

            datos_usuario= obtener_datos_usuario(from_number) 
            session['datos_usuario'+str(from_number)] = datos_usuario
    
            if datos_usuario:
                user_id= datos_usuario['user_id']
                user_ult_login = datos_usuario['ultimo_login']
                user_estado=datos_usuario['estado']
                user_es_baneado=datos_usuario['es_baneado']
                user_documento=datos_usuario['documento']
                user_imagen=datos_usuario['imagen']
                user_deposito=datos_usuario['deposito']
                user_nombre=datos_usuario['nombre']
                user_nick=datos_usuario['nick']
                user_rol_seguridad=datos_usuario['rol_seguridad']
                user_correo=datos_usuario['correo']
                user_apellido=datos_usuario['apellido']
                user_telefono=datos_usuario['telefono']
                user_depo_id=datos_usuario['depo_id']
            else:
                resp.message("Id de usuario desconocido")
                session['step'+str(from_number)] = 0
                return str(resp)
            resp.message(f"Bienvenido a Trazalog Tools Mantenimiento.\n*{user_nombre} {user_apellido}* ({user_correo})\n\n"+ 
                         f"Vamos a ingresar una Solicitud de Servicio 🧰🪛⛏️ para el equipo:\n\n*{equi_codigo}{equi_description} ⚙️* \n\n"+
                         f"Empresa:{equi_empresa} - Marca: {equi_marca} - Sector {equi_sector} - \nGrupo {equi_grupo} - Area: {equi_area} - Crit: {equi_criticidad} - Proc: {equi_proceso}\n\n"+
                        "Por favor ingrese la falla detectada: 📝\n")
            
        elif step == 1:
            session['falla'+str(from_number)] = incoming_msg
            session['images'+str(from_number)] = []
            resp.message("Por favor ingrese una foto 🤳 o responda 1️⃣ para continuar sin más fotos")
        elif step == 2:
            if incoming_msg == "1":
                response_message = create_issue(from_number)
                resp.message(response_message)
                return str(resp)
            else:
                if media_url:
                    app.logger.info(f"media url {media_url}")
                    path_foto = save_media(media_url, from_number)
                    images = session.get('images'+str(from_number), [])
                    images.append(path_foto)
                    session['images'+str(from_number)] = images

                    if len(images) < Config.MAX_IMAGES:
                        resp.message(f"Imagen guardada. Puede subir otra foto 🤳 o responder 1️⃣ para continuar")
                        return str(resp)
                    else:
                        response_message = create_issue(from_number)
                        resp.message(response_message)
                        return str(resp)
                else:
                    resp.message("No se detectó una imagen. Por favor, suba una foto 🤳 o responda 1️⃣ para continuar.")
                    return str(resp)
        elif step == 3:
            response_message = create_issue(from_number)
            resp.message(response_message)
        else:
            step=-1
        step +=1
        app.logger.info(f"setting step {step}")
        session['step'+str(from_number)] = str(step)
        return str(resp)
    except Exception as e:
        step=0
        app.logger.info(f"Error, reseting step {step}")
        app.logger.info(traceback.format_exc())
        session['step'+str(from_number)] = str(step)
        session['equi_id'+str(from_number)] = 0
        return "Error"
if __name__ == '__main__':
    app.run(host=Config.FLASK_HOST,debug=True,port=Config.FLASK_PORT)


