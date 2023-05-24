package com.omnys.geofencing.flutter_geofencing_omnys

import org.altbeacon.beacon.Identifier
import org.altbeacon.beacon.Region

class GeofenceRegion(
    val identifier: String,
    val proximityUUID: String?,
    val major: Int?,
    val minor: Int?
) {

    fun frameworkValue(): Region {
        val ids = mutableListOf<Identifier>()
        if (proximityUUID != null)
            ids.add(Identifier.parse(proximityUUID))
        if (major != null)
            ids.add(Identifier.parse(major.toString()))
        if (minor != null)
            ids.add(Identifier.parse(minor.toString()))
        return Region(identifier, ids)
    }

    companion object {
        fun fromJson(json: Map<String, *>): GeofenceRegion {
            return GeofenceRegion(
                json["identifier"] as String,
                json["proximityUUID"] as String?,
                json["major"] as Int?,
                json["minor"] as Int?,
            );
        }
    }
}

enum class EventType(val dartValue: Int) {
    ENTER(1), EXIT(2)
}