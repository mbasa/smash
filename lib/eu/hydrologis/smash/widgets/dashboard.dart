/*
 * Copyright (c) 2019. Antonello Andrea (www.hydrologis.com). All rights reserved.
 * Use of this source code is governed by a GPL3 license that can be
 * found in the LICENSE file.
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_jts/dart_jts.dart' hide Position;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong/latlong.dart';

import 'package:path/path.dart' hide context;
import 'package:smash/eu/hydrologis/dartlibs/dartlibs.dart';
import 'package:smash/eu/hydrologis/flutterlibs/eventhandlers.dart';
import 'package:smash/eu/hydrologis/flutterlibs/forms/forms.dart';
import 'package:smash/eu/hydrologis/flutterlibs/forms/forms_widgets.dart';
import 'package:smash/eu/hydrologis/flutterlibs/geo/geo.dart';
import 'package:smash/eu/hydrologis/flutterlibs/geo/geopaparazzi/database_widgets.dart';
import 'package:smash/eu/hydrologis/flutterlibs/geo/geopaparazzi/gp_database.dart';
import 'package:smash/eu/hydrologis/smash/core/models.dart';
import 'package:smash/eu/hydrologis/flutterlibs/geo/geopaparazzi/project_tables.dart';
import 'package:smash/eu/hydrologis/flutterlibs/geo/maps/layers.dart';
import 'package:smash/eu/hydrologis/flutterlibs/geo/maps/map_plugins.dart';
import 'package:smash/eu/hydrologis/flutterlibs/util/colors.dart';
import 'package:smash/eu/hydrologis/flutterlibs/util/logging.dart';
import 'package:smash/eu/hydrologis/flutterlibs/util/preferences.dart';
import 'package:smash/eu/hydrologis/flutterlibs/util/screen.dart';
import 'package:smash/eu/hydrologis/flutterlibs/util/share.dart';
import 'package:smash/eu/hydrologis/flutterlibs/util/ui.dart';
import 'package:smash/eu/hydrologis/flutterlibs/util/validators.dart';
import 'package:smash/eu/hydrologis/flutterlibs/workspace.dart';
import 'package:provider/provider.dart';

import 'dashboard_utils.dart';

class DashboardWidget extends StatefulWidget {
  DashboardWidget({Key key}) : super(key: key);

  @override
  _DashboardWidgetState createState() => new _DashboardWidgetState();
}

class _DashboardWidgetState extends State<DashboardWidget> with WidgetsBindingObserver {
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  double _initLon;
  double _initLat;
  double _initZoom;

  MapController _mapController;

  List<LayerOptions> _activeLayers = [];

  Size _media;

  double _iconSize = SmashUI.MEDIUM_ICON_SIZE;

  @override
  void initState() {
    super.initState();
    SmashMapState mapState = Provider.of<SmashMapState>(context, listen: false);
    GpsState gpsState = Provider.of<GpsState>(context, listen: false);
    ProjectState projectState = Provider.of<ProjectState>(context, listen: false);

    _initLon = mapState.center.x;
    _initLat = mapState.center.y;
    _initZoom = mapState.zoom;
    if (_initZoom == 0) _initZoom = 1;
    _mapController = MapController();
    mapState.mapController = _mapController;

    bool doNoteInGps = GpPreferences().getBooleanSync(KEY_DO_NOTE_IN_GPS, true);
    gpsState.insertInGpsQuiet = doNoteInGps;
    // check center on gps
    bool centerOnGps = GpPreferences().getCenterOnGps();
    mapState.centerOnGpsQuiet = centerOnGps;
    // check rotate on heading
    bool rotateOnHeading = GpPreferences().getRotateOnHeading();
    mapState.rotateOnHeadingQuiet = rotateOnHeading;

    ScreenUtilities.keepScreenOn(GpPreferences().getKeepScreenOn());

    _iconSize = GpPreferences().getDoubleSync(KEY_MAPTOOLS_ICON_SIZE, SmashUI.MEDIUM_ICON_SIZE);

    Future.delayed(Duration.zero, () async {
      var directory = await Workspace.getConfigurationFolder();
      bool init = await GpLogger().init(directory.path); // init logger
      if (init) GpLogger().d("Db logger initialized.");

      // set initial status
      bool gpsIsOn = GpsHandler().isGpsOn();
      if (gpsIsOn != null) {
        if (gpsIsOn) {
          gpsState.statusQuiet = GpsStatus.ON_NO_FIX;
        }
      }

      projectState.context = context;
      await projectState.reloadProject();
      await reloadLayers();
    });

    WidgetsBinding.instance.addObserver(this);
  }

  _showSnackbar(snackbar) {
    _scaffoldKey.currentState.showSnackBar(snackbar);
  }

  _hideSnackbar() {
    _scaffoldKey.currentState.hideCurrentSnackBar();
  }

  @override
  Widget build(BuildContext context) {
    print("BUIIIIIILD!!!");

//    return Center(
//      child: Text("TEst"),
//    );
    return Consumer<ProjectState>(builder: (context, projectState, child) {
      projectState.context = context;
      projectState.scaffoldKey = _scaffoldKey;
      return consumeBuild(projectState);
    });
  }

  WillPopScope consumeBuild(ProjectState projectState) {
    _media = MediaQuery.of(projectState.context).size;
    var layers = <LayerOptions>[];

    var mapState = Provider.of<SmashMapState>(projectState.context, listen: false);
    mapState.mapController = _mapController;

    layers.addAll(_activeLayers);

    var projectData = projectState.projectData;
    if (projectData != null) {
      if (projectData.geopapLogs != null) layers.add(projectData.geopapLogs);
      if (projectData.geopapMarkers != null && projectData.geopapMarkers.length > 0) {
        var markerCluster = MarkerClusterLayerOptions(
          maxClusterRadius: 80,
          //        height: 40,
          //        width: 40,
          fitBoundsOptions: FitBoundsOptions(
            padding: EdgeInsets.all(50),
          ),
          markers: projectData.geopapMarkers,
          polygonOptions:
              PolygonOptions(borderColor: SmashColors.mainDecorationsDark, color: SmashColors.mainDecorations.withOpacity(0.2), borderStrokeWidth: 3),
          builder: (context, markers) {
            return FloatingActionButton(
              child: Text(markers.length.toString()),
              onPressed: null,
              backgroundColor: SmashColors.mainDecorationsDark,
              foregroundColor: SmashColors.mainBackground,
              heroTag: null,
            );
          },
        );
        layers.add(markerCluster);
      }
    }

    layers.add(CurrentGpsLogPluginOption(
      logColor: Colors.red,
      logWidth: 5.0,
    ));

    layers.add(GpsPositionPluginOption(
      markerColor: Colors.black,
      markerSize: 32,
    ));

    bool showScalebar = GpPreferences().getBooleanSync(KEY_SHOW_SCALEBAR, true);
    if (showScalebar) {
      layers.add(ScaleLayerPluginOption(
        lineColor: Colors.black,
        lineWidth: 3,
        textStyle: TextStyle(color: Colors.black, fontSize: 14),
        padding: EdgeInsets.all(10),
      ));
    }

    var centerCrossStyle = CenterCrossStyle.fromPreferences();
    if (centerCrossStyle.visible) {
      layers.add(CenterCrossPluginOption(
        crossColor: ColorExt(centerCrossStyle.color),
        crossSize: centerCrossStyle.size,
        lineWidth: centerCrossStyle.lineWidth,
      ));
    }

    return WillPopScope(
        // check when the app is left
        child: new Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: Padding(
              padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
              child: Image.asset("assets/smash_text.png", fit: BoxFit.fitHeight),
            ),
            actions: <Widget>[
              IconButton(
                  icon: Icon(Icons.info_outline),
                  onPressed: () {
                    showInfoDialog(projectState.context, "Project: ${projectState.projectName}\nDatabase: ${projectState.projectPath}".trim(), widgets: [
                      IconButton(
                        icon: Icon(
                          Icons.share,
                          color: SmashColors.mainDecorations,
                        ),
                        onPressed: () async {
                          ShareHandler.shareProject(projectState.context);
                        },
                      )
                    ]);
                  })
            ],
          ),
          backgroundColor: SmashColors.mainBackground,
          body: FlutterMap(
            options: new MapOptions(
              center: new LatLng(_initLat, _initLon),
              zoom: _initZoom,
              minZoom: SmashMapState.MINZOOM,
              maxZoom: SmashMapState.MAXZOOM,
              plugins: [
                MarkerClusterPlugin(),
                ScaleLayerPlugin(),
                CenterCrossPlugin(),
                CurrentGpsLogPlugin(),
                GpsPositionPlugin(),
              ],
              onPositionChanged: (newPosition, hasGesture) {
                mapState.setLastPosition(Coordinate(newPosition.center.longitude, newPosition.center.latitude), newPosition.zoom);
              },
            ),
            layers: layers,
            mapController: _mapController,
          ),
          drawer: Drawer(
              child: ListView(
            children: _getDrawerWidgets(projectState.context),
          )),
          endDrawer: Drawer(
              child: ListView(
            children: _getEndDrawerWidgets(projectState.context),
          )),
          bottomNavigationBar: BottomAppBar(
            color: SmashColors.mainDecorations,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                DashboardUtils.makeToolbarBadge(
                  GestureDetector(
                    child: IconButton(
                      onPressed: () async {
                        var gpsState = Provider.of<GpsState>(projectState.context, listen: false);
                        var doNoteInGps = gpsState.insertInGps;
                        Widget titleWidget = getDialogTitleWithInsertionMode("Simple Notes", doNoteInGps, SmashColors.mainSelection);
                        List<String> types = ["note", "image"];
                        var selectedType = await showComboDialog(projectState.context, titleWidget, types);
                        if (selectedType == types[0]) {
                          Note note = await DataLoaderUtilities.addNote(projectState, doNoteInGps, _mapController);
                          Navigator.push(projectState.context, MaterialPageRoute(builder: (context) => NotePropertiesWidget(note)));
                        } else if (selectedType == types[1]) {
                          DataLoaderUtilities.addImage(projectState.context, doNoteInGps ? gpsState.lastGpsPosition : _mapController.center);
                        }
                      },
                      icon: Icon(
                        Icons.note,
                        color: SmashColors.mainBackground,
                      ),
                      iconSize: _iconSize,
                    ),
                    onLongPress: () {
                      Navigator.push(projectState.context, MaterialPageRoute(builder: (context) => NotesListWidget(true)));
                    },
                  ),
                  projectData != null ? projectData.simpleNotesCount : 0,
                ),
                DashboardUtils.makeToolbarBadge(
                  GestureDetector(
                    child: IconButton(
                      onPressed: () async {
                        var gpsState = Provider.of<GpsState>(projectState.context, listen: false);
                        var doNoteInGps = gpsState.insertInGps;
                        var title = "Select form";
                        Widget titleWidget = getDialogTitleWithInsertionMode(title, doNoteInGps, SmashColors.mainSelection);

                        var allSectionsMap = TagsManager().getSectionsMap();
                        List<String> sectionNames = allSectionsMap.keys.toList();
                        List<String> iconNames = [];
                        sectionNames.forEach((key) {
                          var icon4section = TagsManager.getIcon4Section(allSectionsMap[key]);
                          iconNames.add(icon4section);
                        });

                        var selectedSection = await showComboDialog(projectState.context, titleWidget, sectionNames, iconNames);
                        if (selectedSection != null) {
                          Widget appbarWidget = getDialogTitleWithInsertionMode(selectedSection, doNoteInGps, SmashColors.mainBackground);

                          var selectedIndex = sectionNames.indexOf(selectedSection);
                          var iconName = iconNames[selectedIndex];
                          var sectionMap = allSectionsMap[selectedSection];
                          var jsonString = jsonEncode(sectionMap);
                          Note note = await DataLoaderUtilities.addNote(projectState, doNoteInGps, _mapController,
                              text: selectedSection, form: jsonString, iconName: iconName, color: ColorExt.asHex(SmashColors.mainDecorationsDark));

                          Navigator.push(projectState.context, MaterialPageRoute(
                            builder: (context) {
                              return MasterDetailPage(
                                  sectionMap, appbarWidget, selectedSection, doNoteInGps ? gpsState.lastGpsPosition : _mapController.center, note.id);
                            },
                          ));
                        }
                      },
                      icon: Icon(
                        Icons.note_add,
                        color: SmashColors.mainBackground,
                      ),
                      iconSize: _iconSize,
                    ),
                    onLongPress: () {
                      Navigator.push(projectState.context, MaterialPageRoute(builder: (context) => NotesListWidget(false)));
                    },
                  ),
                  projectData != null ? projectData.formNotesCount : 0,
                ),
                DashboardUtils.makeToolbarBadge(
                  LoggingButton(_iconSize),
                  projectData != null ? projectData.logsCount : 0,
                ),
                Spacer(),
                GpsInfoButton(_iconSize),
                Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.layers,
                    color: SmashColors.mainBackground,
                  ),
                  iconSize: _iconSize,
                  onPressed: () {
                    Navigator.push(projectState.context, MaterialPageRoute(builder: (context) => LayersPage(reloadLayers)));
                  },
                  color: SmashColors.mainBackground,
                  tooltip: 'Open layers list',
                ),
                Consumer<SmashMapState>(builder: (context, mapState, child) {
                  return DashboardUtils.makeToolbarZoomBadge(
                    IconButton(
                      onPressed: () {
                        mapState.zoomIn();
                      },
                      tooltip: 'Zoom in',
                      icon: Icon(
                        Icons.zoom_in,
                        color: SmashColors.mainBackground,
                      ),
                      iconSize: _iconSize,
                    ),
                    mapState.zoom.toInt(),
                  );
                }),
                IconButton(
                  onPressed: () {
                    mapState.zoomOut();
                  },
                  tooltip: 'Zoom out',
                  icon: Icon(
                    Icons.zoom_out,
                    color: SmashColors.mainBackground,
                  ),
                  iconSize: _iconSize,
                ),
              ],
            ),
          ),
        ),
        onWillPop: () async {
          bool doExit = await showConfirmDialog(projectState.context, "Are you sure you want to exit?", "Active operations will be stopped.");
          if (doExit) {
            dispose();
            return Future.value(true);
          }
          return Future.value(false);
        });
  }

  Widget getDialogTitleWithInsertionMode(String title, bool doNoteInGps, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: SmashUI.defaultRigthPadding(),
          child: SmashUI.titleText(title, color: color, bold: true),
        ),
        doNoteInGps
            ? Icon(
                Icons.gps_fixed,
                color: color,
              )
            : Icon(
                Icons.center_focus_weak,
                color: color,
              ),
      ],
    );
  }

  _getDrawerWidgets(BuildContext context) {
    double iconSize = 48;
    double textSize = iconSize / 2;
    var c = SmashColors.mainDecorations;
    return [
      new Container(
        margin: EdgeInsets.only(bottom: 20),
        child: new DrawerHeader(child: Image.asset("assets/smash_icon.png")),
        color: SmashColors.mainBackground,
      ),
      new Container(
        child: new Column(children: DashboardUtils.getDrawerTilesList(context, _mapController)),
      ),
    ];
  }

  _getEndDrawerWidgets(BuildContext context) {
    return [
      new Container(
        margin: EdgeInsets.only(bottom: 20),
        child: new DrawerHeader(child: Image.asset("assets/maptools_icon.png")),
        color: SmashColors.mainBackground,
      ),
      new Container(
        child: new Column(children: DashboardUtils.getEndDrawerListTiles(context, _mapController)),
      ),
    ];
  }

  @override
  void dispose() {
    updateCenterPosition();
    WidgetsBinding.instance.removeObserver(this);

    ProjectState projectState = Provider.of<ProjectState>(context, listen: false);
    projectState?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
//      GpLogger().d("Application suspended");
      updateCenterPosition();
    } else if (state == AppLifecycleState.inactive) {
//      GpLogger().d("Application inactived");
      updateCenterPosition();
    } else if (state == AppLifecycleState.resumed) {
//      GpLogger().d("Application resumed");
    }
  }

  void updateCenterPosition() {
    // save last position
    SmashMapState mapState = Provider.of<SmashMapState>(context, listen: false);
    if (mapState != null) {
      mapState.setLastPosition(Coordinate(_mapController.center.longitude, _mapController.center.latitude), _mapController.zoom);
    }
  }

  Future<void> reloadLayers() async {
    var activeLayersInfos = LayerManager().getActiveLayers();
    _activeLayers = [];

    List<LayerOptions> listTmp = [];
    for (int i = 0; i < activeLayersInfos.length; i++) {
      var ls = await activeLayersInfos[i].toLayers(_showSnackbar);
      if (ls != null) {
        ls.forEach((l) => listTmp.add(l));
      }
      GpLogger().d("Layer loaded: ${activeLayersInfos[i].toJson()}");
    }
    setState(() {
      _activeLayers.addAll(listTmp);
    });
  }

  Future doExit(BuildContext context) async {
    ProjectState projectState = Provider.of<ProjectState>(context, listen: false);
    await projectState?.close();
    await SystemChannels.platform.invokeMethod<void>('SystemNavigator.pop');
  }
}

/// Class to hold the state of the GPS info button, updated by the gps state notifier.
///
class GpsInfoButton extends StatefulWidget {
  double _iconSize;

  GpsInfoButton(this._iconSize);

  @override
  State<StatefulWidget> createState() => _GpsInfoButtonState();
}

class _GpsInfoButtonState extends State<GpsInfoButton> {
  _GpsInfoButtonState();

  @override
  Widget build(BuildContext context) {
    return Consumer<GpsState>(builder: (context, gpsState, child) {
      return GestureDetector(
        onLongPress: () {
          if (gpsState.hasFix()) {
            var isLandscape = ScreenUtilities.isLandscape(context);
            if (isLandscape) {
              Scaffold.of(context).showSnackBar(SnackBar(
                backgroundColor: SmashColors.mainDecorations,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 20),
                            child: getGpsInfoContainer(),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 20),
                            child: GpsToolsWidget(),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: getBottomButtons(context),
                    ),
                  ],
                ),
                duration: Duration(seconds: 5),
              ));
            } else {
              Scaffold.of(context).showSnackBar(SnackBar(
                backgroundColor: SmashColors.mainDecorations,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: getGpsInfoContainer(),
                    ),
                    Divider(
                      color: SmashColors.mainBackground,
                      height: 5,
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 10, bottom: 5),
                      child: GpsToolsWidget(),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: getBottomButtons(context),
                    ),
                  ],
                ),
                duration: Duration(seconds: 15),
              ));
            }
          }
        },
        child: Transform.scale(
          scale: 1.3,
          child: FloatingActionButton(
            elevation: 1,
            backgroundColor: SmashColors.mainDecorations,
            child: DashboardUtils.getGpsStatusIcon(gpsState.status),

//          iconSize: widget._iconSize,
            onPressed: () {
              if (gpsState.hasFix() || gpsState.status == GpsStatus.ON_NO_FIX) {
                var pos = gpsState.lastGpsPosition;
                SmashMapState mapState = Provider.of<SmashMapState>(context, listen: false);
                if (pos != null) {
                  var newCenter = Coordinate(pos.longitude, pos.latitude);
                  mapState.center = newCenter;
                }
              }
            },
          ),
        ),
      );
    });
  }

  Widget getBottomButtons(BuildContext context) {
    return Consumer<GpsState>(builder: (context, gpsState, child) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          gpsState.lastGpsPosition != null
              ? IconButton(
                  icon: Icon(
                    Icons.content_copy,
                    color: SmashColors.mainBackground,
                  ),
                  tooltip: "Copy position to clipboard.",
                  iconSize: SmashUI.MEDIUM_ICON_SIZE,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: gpsState.lastGpsPosition.toString()));
                  },
                )
              : Container(),
          Spacer(
            flex: 1,
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: SmashColors.mainBackground,
            ),
            iconSize: SmashUI.MEDIUM_ICON_SIZE,
            onPressed: () {
              Scaffold.of(context).hideCurrentSnackBar();
            },
          ),
        ],
      );
    });
  }

  Widget getGpsInfoContainer() {
    var color = SmashColors.mainBackground;

    return Consumer<GpsState>(builder: (context, gpsState, child) {
      Widget gpsInfo;
      if (gpsState.hasFix() && gpsState.lastGpsPosition != null) {
        var pos = gpsState.lastGpsPosition;
        gpsInfo = Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
//              crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: SmashUI.titleText(
                "Last GPS position",
                textAlign: TextAlign.center,
                bold: true,
                color: color,
              ),
            ),
            Table(
              columnWidths: {
                0: FlexColumnWidth(0.4),
                1: FlexColumnWidth(0.6),
              },
              children: [
                TableRow(
                  children: [
                    TableUtilities.cellForString("Latitude", color: color),
                    TableUtilities.cellForString("${pos.latitude} deg", color: color),
                  ],
                ),
                TableRow(
                  children: [
                    TableUtilities.cellForString("Longitude", color: color),
                    TableUtilities.cellForString("${pos.longitude} deg", color: color),
                  ],
                ),
                TableRow(
                  children: [
                    TableUtilities.cellForString("Altitude", color: color),
                    TableUtilities.cellForString("${pos.altitude.round()} m", color: color),
                  ],
                ),
                TableRow(
                  children: [
                    TableUtilities.cellForString("Accuracy", color: color),
                    TableUtilities.cellForString("${pos.accuracy.round()} m", color: color),
                  ],
                ),
                TableRow(
                  children: [
                    TableUtilities.cellForString("Heading", color: color),
                    TableUtilities.cellForString("${pos.heading.round()} deg", color: color),
                  ],
                ),
                TableRow(
                  children: [
                    TableUtilities.cellForString("Speed", color: color),
                    TableUtilities.cellForString("${pos.speed.toInt()} m/s", color: color),
                  ],
                ),
                TableRow(
                  children: [
                    TableUtilities.cellForString("Timestamp", color: color),
                    TableUtilities.cellForString("${TimeUtilities.ISO8601_TS_FORMATTER.format(pos.timestamp)}", color: color),
                  ],
                ),
              ],
            ),
          ],
        );
      } else {
        gpsInfo = SmashUI.titleText(
          "No GPS information available...",
          color: color,
        );
      }

      return Container(
        child: gpsInfo,
      );
    });
  }
}

class GpsToolsWidget extends StatefulWidget {
  GpsToolsWidget();

  @override
  State<StatefulWidget> createState() => _GpsToolsWidgetState();
}

class _GpsToolsWidgetState extends State<GpsToolsWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SmashMapState>(builder: (context, mapState, child) {
      Widget toolsWidget = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: SmashUI.titleText(
              "Tools",
              textAlign: TextAlign.center,
              color: SmashColors.mainBackground,
              bold: true,
            ),
          ),
          CheckboxListTile(
            value: mapState.centerOnGps,
            title: SmashUI.normalText("Center map on GPS position", color: SmashColors.mainBackground),
            onChanged: (value) {
              mapState.centerOnGps = value;
            },
          ),
          Platform.isAndroid
              ? CheckboxListTile(
                  value: mapState.rotateOnHeading,
                  title: SmashUI.normalText("Rotate map with GPS heading", color: SmashColors.mainBackground),
                  onChanged: (value) {
                    mapState.rotateOnHeading = value;
                  },
                )
              : Container(),
        ],
      );
      return Container(
        child: toolsWidget,
      );
    });
  }
}

/// Class to hold the state of the GPS info button, updated by the gps state notifier.
///
class LoggingButton extends StatefulWidget {
  double _iconSize;

  LoggingButton(this._iconSize);

  @override
  State<StatefulWidget> createState() => _LoggingButtonState();
}

class _LoggingButtonState extends State<LoggingButton> {
  @override
  Widget build(BuildContext context) {
    return Consumer<GpsState>(builder: (context, gpsState, child) {
      return GestureDetector(
        child: IconButton(
            icon: DashboardUtils.getLoggingIcon(gpsState.status),
            iconSize: widget._iconSize,
            onPressed: () {
              _toggleLoggingFunction(context, gpsState);
            }),
        onLongPress: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => LogListWidget()));
        },
      );
    });
  }

  _toggleLoggingFunction(BuildContext context, GpsState gpsLoggingState) async {
    if (gpsLoggingState.isLogging) {
      var stopLogging = await showConfirmDialog(context, "Stop Logging?", "Stop logging and close the current GPS log?");
      if (stopLogging) {
        await gpsLoggingState.stopLogging();
        ProjectState projectState = Provider.of<ProjectState>(context, listen: false);
        projectState.reloadProject();
      }
    } else {
      if (GpsHandler().hasFix()) {
        String logName = "log_${TimeUtilities.DATE_TS_FORMATTER.format(DateTime.now())}";

        String userString = await showInputDialog(
          context,
          "New Log",
          "Enter a name for the new log",
          hintText: '',
          defaultText: logName,
          validationFunction: noEmptyValidator,
        );

        if (userString != null) {
          if (userString.trim().length == 0) userString = logName;
          int logId = await gpsLoggingState.startLogging(logName);
          if (logId == null) {
            // TODO show error
          }
        }
      } else {
        showOperationNeedsGps(context);
      }
    }
  }
}
