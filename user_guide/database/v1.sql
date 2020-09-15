-- MySQL dump 10.13  Distrib 5.7.17, for Win64 (x86_64)
--
-- Host: 127.0.0.1    Database: formularios
-- ------------------------------------------------------
-- Server version	5.5.5-10.1.31-MariaDB

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `frm_formularios`
--

DROP TABLE IF EXISTS `frm_formularios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `frm_formularios` (
  `form_id` int(11) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(45) CHARACTER SET latin1 DEFAULT NULL,
  `descripcion` varchar(300) CHARACTER SET latin1 DEFAULT NULL,
  `empr_id` int(11) DEFAULT NULL,
  `fec_alta` datetime DEFAULT CURRENT_TIMESTAMP,
  `eliminado` tinyint(4) DEFAULT '0',
  PRIMARY KEY (`form_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8 COLLATE=utf8_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `frm_formularios`
--

LOCK TABLES `frm_formularios` WRITE;
/*!40000 ALTER TABLE `frm_formularios` DISABLE KEYS */;
INSERT INTO `frm_formularios` VALUES (1,'Formulario Usuario','-',1,'2019-08-17 14:24:38',0);
/*!40000 ALTER TABLE `frm_formularios` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `frm_instacia_formularios`
--

DROP TABLE IF EXISTS `frm_instacia_formularios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `frm_instacia_formularios` (
  `item_id` int(11) NOT NULL,
  `info_id` int(11) NOT NULL,
  `valor` varchar(500) COLLATE utf8_spanish_ci DEFAULT NULL,
  `fec_alta` datetime DEFAULT CURRENT_TIMESTAMP,
  `eliminado` tinyint(4) DEFAULT '0',
  PRIMARY KEY (`item_id`,`info_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `frm_instacia_formularios`
--

LOCK TABLES `frm_instacia_formularios` WRITE;
/*!40000 ALTER TABLE `frm_instacia_formularios` DISABLE KEYS */;
/*!40000 ALTER TABLE `frm_instacia_formularios` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `frm_items`
--

DROP TABLE IF EXISTS `frm_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `frm_items` (
  `item_id` int(11) NOT NULL AUTO_INCREMENT,
  `label` varchar(45) COLLATE utf8_spanish_ci DEFAULT NULL,
  `name` varchar(45) COLLATE utf8_spanish_ci DEFAULT NULL,
  `requerido` tinyint(4) DEFAULT NULL,
  `tida_id` varchar(45) COLLATE utf8_spanish_ci DEFAULT NULL,
  `valo_id` varchar(45) COLLATE utf8_spanish_ci DEFAULT NULL,
  `form_id` int(11) DEFAULT NULL,
  `orden` int(11) DEFAULT NULL,
  `fec_alta` datetime DEFAULT CURRENT_TIMESTAMP,
  `eliminado` tinyint(4) DEFAULT '0',
  `aux` varchar(45) COLLATE utf8_spanish_ci DEFAULT NULL,
  PRIMARY KEY (`item_id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8 COLLATE=utf8_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `frm_items`
--

LOCK TABLES `frm_items` WRITE;
/*!40000 ALTER TABLE `frm_items` DISABLE KEYS */;
INSERT INTO `frm_items` VALUES (1,'Complete todos los campos del formulario *',NULL,NULL,'2',NULL,1,1,'2019-08-17 14:27:38',0,NULL),(2,'Nombre','nombre',1,'3',NULL,1,2,'2019-08-17 14:28:46',0,NULL),(3,'Apellido','apellido',1,'3',NULL,1,3,'2019-08-17 14:28:46',0,NULL),(4,'Fecha Nacimiento','fecha_nacimiento',1,'5',NULL,1,4,'2019-08-17 14:32:37',0,NULL),(5,'Email','email',1,'3',NULL,1,5,'2019-08-17 14:34:08',0,NULL),(6,'Seleccionar Provincia','provincia',1,'4','provincias',1,6,'2019-08-17 14:34:57',0,NULL),(7,'Seleccionar Sexo','sexo',1,'7','sexos',1,7,'2019-08-17 15:40:06',0,NULL),(8,'Seleccionar Opcion','contrato',1,'6','contratos',1,8,'2019-08-17 15:40:06',0,NULL),(9,'Adjuntar Archivo','pdf',1,'8',NULL,1,9,'2019-08-17 15:42:37',0,NULL),(10,'Observaciones','observaciones',1,'9',NULL,1,10,'2019-08-17 15:42:37',0,NULL);
/*!40000 ALTER TABLE `frm_items` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `frm_tipos_datos`
--

DROP TABLE IF EXISTS `frm_tipos_datos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `frm_tipos_datos` (
  `tida_id` int(11) NOT NULL AUTO_INCREMENT,
  `tipo` varchar(45) COLLATE utf8_spanish_ci DEFAULT NULL,
  `fec_alta` datetime DEFAULT CURRENT_TIMESTAMP,
  `eliminado` tinyint(4) DEFAULT '0',
  PRIMARY KEY (`tida_id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8 COLLATE=utf8_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `frm_tipos_datos`
--

LOCK TABLES `frm_tipos_datos` WRITE;
/*!40000 ALTER TABLE `frm_tipos_datos` DISABLE KEYS */;
INSERT INTO `frm_tipos_datos` VALUES (1,'titulo','2019-08-17 14:10:08',0),(2,'comentario','2019-08-17 14:10:08',0),(3,'input','2019-08-17 14:10:08',0),(4,'select','2019-08-17 14:10:08',0),(5,'date','2019-08-17 14:10:08',0),(6,'check','2019-08-17 14:10:08',0),(7,'radio','2019-08-17 14:10:08',0),(8,'file','2019-08-17 14:10:08',0),(9,'textarea','2019-08-17 14:24:06',0);
/*!40000 ALTER TABLE `frm_tipos_datos` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `utl_tablas`
--

DROP TABLE IF EXISTS `utl_tablas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `utl_tablas` (
  `tabl_id` int(11) NOT NULL,
  `tabla` varchar(50) COLLATE utf8_spanish_ci DEFAULT NULL,
  `valor` varchar(50) COLLATE utf8_spanish_ci DEFAULT NULL,
  `descripcion` varchar(200) COLLATE utf8_spanish_ci DEFAULT NULL,
  `fec_alta` datetime DEFAULT CURRENT_TIMESTAMP,
  `eliminado` tinyint(4) DEFAULT '0',
  PRIMARY KEY (`tabl_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `utl_tablas`
--

LOCK TABLES `utl_tablas` WRITE;
/*!40000 ALTER TABLE `utl_tablas` DISABLE KEYS */;
INSERT INTO `utl_tablas` VALUES (1,'provincias','San Juan',NULL,'2019-08-17 15:33:52',0),(2,'provincias','Mendoza',NULL,'2019-08-17 15:33:52',0),(3,'provincias','San Luis',NULL,'2019-08-17 15:33:52',0),(4,'sexos','Hombre',NULL,'2019-08-17 16:28:10',0),(5,'sexos','Mujer',NULL,'2019-08-17 16:28:10',0),(6,'sexos','No Binario',NULL,'2019-08-17 16:28:10',0),(7,'contratos','Acepto los Terminos y Condiciones del Servicio',NULL,'2019-08-17 17:01:22',0),(8,'contratos','Enviar Emails',NULL,'2019-08-17 17:01:22',0);
/*!40000 ALTER TABLE `utl_tablas` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping routines for database 'formularios'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2019-08-18 17:43:41
