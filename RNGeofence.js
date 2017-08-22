
import { NativeModules } from 'react-native';
const {NativeEventEmitter} = require('react-native');
const { RNGeofence } = NativeModules;
const EventEmitter = new NativeEventEmitter(RNGeofence);

var emptyFn = function() {};

var GeoFenceAPI = {
    events: [
        'geofence',
        'location'
    ],

    configure: function(config, success, failure) {
        success = success || emptyFn;
        failure = failure || emptyFn;
        RNGeofence.configure(config, success, failure);
    },
    setConfig: function(config, success, failure) {
        success = success || emptyFn;
        failure = failure || emptyFn;
        RNGeofence.setConfig(config, success, failure);
    },
    requestLocation: function(){
        RNGeofence.requestLocation();
    },
    addListener: function(event, callback) {
        if (this.events.indexOf(event) < 0) {
            throw "RNGeofence: Unknown event '" + event + '"';
        }
        return EventEmitter.addListener(event, callback);
    },
    on: function(event, callback) {
        return this.addListener(event, callback);
    },
    removeListener: function(event, callback) {
        if (this.events.indexOf(event) < 0) {
            throw "RNGeofence: Unknown event '" + event + '"';
        }
        return EventEmitter.removeListener(event, callback);
    },
    un: function(event, callback) {
        this.removeListener(event, callback);
    },
    onGeofence: function(callback) {
        return EventEmitter.addListener("geofence", callback);
    },
    onLocation: function(callback) {
        return EventEmitter.addListener("location", callback);
    },
    addGeofence: function(config, success, failure) {
        success = success || emptyFn;
        failure = failure || emptyFn;
        RNGeofence.addGeofence(config, success, failure);
    },
    removeGeofence: function(identifier, success, failure) {
        success = success || emptyFn;
        failure = failure || emptyFn;
        RNGeofence.removeGeofence(identifier, success, failure);
    },
    removeGeofences: function(success, failure) {
        success = success || emptyFn;
        failure = failure || emptyFn;
        RNGeofence.removeGeofences(success, failure);
    },
}



export default GeoFenceAPI;
