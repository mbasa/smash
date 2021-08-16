/*
 * Copyright (c) 2019-2020. Antonello Andrea (www.hydrologis.com). All rights reserved.
 * Use of this source code is governed by a GPL3 license that can be
 * found in the LICENSE file.
 */

/*
 * gpslog table name.
 */
import 'package:latlong2/latlong.dart';
import 'package:dart_hydrologis_utils/dart_hydrologis_utils.dart';

final String TABLE_GPSLOGS = "gpslogs";
/*
 * gpslog data table name.
 */
final String TABLE_GPSLOG_DATA = "gpslogsdata";
/*
 * gpslog properties table name.
 */
final String TABLE_GPSLOG_PROPERTIES = "gpslogsproperties";

/*
 * id of the log, Generated by the db.
 */
final String LOGS_COLUMN_ID = "_id";
/*
 * the start UTC timestamp.
 */
final String LOGS_COLUMN_STARTTS = "startts";
/*
 * the end UTC timestamp.
 */
final String LOGS_COLUMN_ENDTS = "endts";
/*
 * The length of the track in meters, as last updated.
 */
final String LOGS_COLUMN_LENGTHM = "lengthm";
/*
 * Is dirty field =0=false, 1=true)
 */
final String LOGS_COLUMN_ISDIRTY = "isdirty";
/*
 * the name of the log.
 */
final String LOGS_COLUMN_TEXT = "text";

/*
 * id of the log, Generated by the db.
 */
final String LOGSPROP_COLUMN_ID = "_id";
/*
 * field for log visibility.
 */
final String LOGSPROP_COLUMN_VISIBLE = "visible";
/*
 * the lgo stroke width.
 */
final String LOGSPROP_COLUMN_WIDTH = "width";
/*
 * the log stroke color.
 */
final String LOGSPROP_COLUMN_COLOR = "color";
/*
 * the id of the parent gps log.
 */
final String LOGSPROP_COLUMN_LOGID = "logid";

/*
 * id of the log point, Generated by the db.
 */
final String LOGSDATA_COLUMN_ID = "_id";
/*
 * the longitude of the point.
 */
final String LOGSDATA_COLUMN_LON = "lon";
/*
 * the latitude of the point.
 */
final String LOGSDATA_COLUMN_LAT = "lat";
/*
 * the accuracy of the point.
 */
final String LOGSDATA_COLUMN_ACCURACY = "accuracy";
/*
 * the elevation of the point.
 */
final String LOGSDATA_COLUMN_ALTIM = "altim";
/*
 * the UTC timestamp
 */
final String LOGSDATA_COLUMN_TS = "ts";
/*
 * the id of the parent gps log.
 */
final String LOGSDATA_COLUMN_LOGID = "logid";

/*
 * the longitude of the point.
 */
final String LOGSDATA_COLUMN_LON_FILTERED = "filtered_lon";
/*
 * the latitude of the point.
 */
final String LOGSDATA_COLUMN_LAT_FILTERED = "filtered_lat";
/*
 * the accuracy of the point.
 */
final String LOGSDATA_COLUMN_ACCURACY_FILTERED = "filtered_accuracy";

class Log {
  int id;
  int startTime;
  int endTime;
  double lengthm;
  String text;
  int isDirty;

  Map<String, dynamic> toMap() {
    var map = {
      LOGS_COLUMN_STARTTS: startTime,
      LOGS_COLUMN_ENDTS: endTime,
      LOGS_COLUMN_LENGTHM: lengthm,
      LOGS_COLUMN_TEXT: text == null
          ? TimeUtilities.ISO8601_TS_FORMATTER.format(new DateTime.now())
          : text,
      LOGS_COLUMN_ISDIRTY: isDirty,
    };
    if (id != null) {
      map[LOGS_COLUMN_ID] = id;
    }
    return map;
  }
}

class LogProperty {
  int id;
  int isVisible;
  double width;
  String color;
  int logid;

  Map<String, dynamic> toMap() {
    var map = {
      LOGSPROP_COLUMN_COLOR: color,
      LOGSPROP_COLUMN_VISIBLE: isVisible,
      LOGSPROP_COLUMN_WIDTH: width,
      LOGSPROP_COLUMN_LOGID: logid,
    };
    if (id != null) {
      map[LOGSPROP_COLUMN_ID] = id;
    }
    return map;
  }
}

class LogDataPoint {
  int id;
  double lon;
  double lat;
  double accuracy;
  double filtered_lon;
  double filtered_lat;
  double filtered_accuracy;
  double altim;
  int ts;
  int logid;

  // not mapped to db
  double speed;

  Map<String, dynamic> toMap() {
    var map = {
      LOGSDATA_COLUMN_LAT: lat,
      LOGSDATA_COLUMN_LON: lon,
      LOGSDATA_COLUMN_ALTIM: altim,
      LOGSDATA_COLUMN_TS: ts,
      LOGSDATA_COLUMN_LOGID: logid,
    };
    if (id != null) {
      map[LOGSDATA_COLUMN_ID] = id;
    }
    if (accuracy != null) {
      map[LOGSDATA_COLUMN_ACCURACY] = accuracy;
    }
    if (filtered_accuracy != null) {
      map[LOGSDATA_COLUMN_ACCURACY_FILTERED] = filtered_accuracy;
      map[LOGSDATA_COLUMN_LAT_FILTERED] = filtered_lat;
      map[LOGSDATA_COLUMN_LON_FILTERED] = filtered_lon;
    }
    return map;
  }
}
