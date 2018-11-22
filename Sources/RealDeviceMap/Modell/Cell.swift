//
//  Cell.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 22.11.18.
//

import Foundation
import PerfectLib
import PerfectMySQL
import S2Geometry

class Cell: JSONConvertibleObject {
    
    var id: UInt64
    var level: UInt8
    var centerLat: Double
    var centerLon: Double
    var updated: UInt32?
    
    override func getJSONValues() -> [String : Any] {
        
        let s2cell = S2Cell(cellId: S2CellId(uid: id))
        var polygon =  [[Double]]()
        for i in 0...3 {
            polygon.append([
                S2LatLng(point: s2cell.getVertex(i)).lat.degrees,
                S2LatLng(point: s2cell.getVertex(i)).lng.degrees
            ])
        }
        
        return [
            "id": id,
            "level": level,
            "updated": updated ?? 1,
            "polygon": polygon
        ]
    }
    
    init(id: UInt64, level: UInt8, centerLat: Double, centerLon: Double, updated: UInt32?) {
        self.id = id
        self.level = level
        self.centerLat = centerLat
        self.centerLon = centerLon
        self.updated = updated
    }
    
    public func save(mysql: MySQL?=nil, update: Bool!=true) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[CELL] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        var sql = """
        INSERT INTO `s2cell` (id, level, center_lat, center_lon, updated)
        VALUES (?, ?, ?, ?, UNIX_TIMESTAMP())
        """
        if update {
            sql += """
            ON DUPLICATE KEY UPDATE
            level=VALUES(level),
            center_lat=VALUES(center_lat),
            center_lon=VALUES(center_lon),
            updated=VALUES(updated)
            """
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)
        mysqlStmt.bindParam(level)
        mysqlStmt.bindParam(centerLat)
        mysqlStmt.bindParam(centerLon)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[CELL] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        
    }

    public static func getAll(mysql: MySQL?=nil, minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, updated: UInt32) throws -> [Cell] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[CELL] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
        SELECT id, level, center_lat, center_lon, updated
        FROM s2cell
        WHERE center_lat >= ? AND center_lat <= ? AND center_lon >= ? AND center_lon <= ? AND updated > ?
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(minLat)
        mysqlStmt.bindParam(maxLat)
        mysqlStmt.bindParam(minLon)
        mysqlStmt.bindParam(maxLon)
        mysqlStmt.bindParam(updated)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[CELL] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var cells = [Cell]()
        while let result = results.next() {
            
            let id = result[0] as! UInt64
            let level = result[1] as! UInt8
            let centerLat = result[2] as! Double
            let centerLon = result[3] as! Double
            let updated = result[4] as! UInt32
        
            cells.append(Cell(id: id, level: level, centerLat: centerLat, centerLon: centerLon, updated: updated))
        }
        return cells
        
    }

    
}