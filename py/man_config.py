class Config:
    TOOLS_API_SERVER="10.142.0.11:8283"
    TOOLS_API_URL = f"http://{TOOLS_API_SERVER}"
    IMAGE_SAVE_DIRECTORY = '/var/www/html/tools/traz-prod-assetplanner/assets/images'
    WHA_TOOLS_PATTERN = r'^TTOOLS-SOLSERV-(\d+)$'
    FLASK_HOST='0.0.0.0'
    FLASK_PORT=3651
    LOG_NAME='whasolservreceiver.log'
    MAX_IMAGES = 7
    #to make it work, you should also add     TWILIO_ACCOUNT_SID and TWILIO_ACCOUNT_TOKEN params
    
