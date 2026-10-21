import math
from geopy.distance import geodesic

class Quadtree:
    
    #bounds is a dictionary with lat and long coords
    def __init__(self, incident_points, bounds=None, depth=0):
        
        self.incident_points = incident_points
        self.max_depth = 20
        self.depth = depth
        self.has_children = False
        self.max_points_per_region = 8
        
        if bounds is None:
            print("Creating quadtree of incidents...")

            #create square around all points
            created_bounds = self.find_bounds(incident_points)
            self.min_lat = created_bounds["min_lat"]
            self.max_lat = created_bounds["max_lat"]
            self.min_long = created_bounds["min_long"]
            self.max_long = created_bounds["max_long"]
        else:
            self.min_lat = bounds["min_lat"]
            self.max_lat = bounds["max_lat"]
            self.min_long = bounds["min_long"]
            self.max_long = bounds["max_long"]
        
        #now calculate these values for convenience 
        lat_dist = self.max_lat - self.min_lat
        long_dist = self.max_long - self.min_long
        self.mid_lat = self.min_lat + (0.5*lat_dist)
        self.mid_long = self.min_long + (0.5*long_dist)

        #early exit here
        if (len(incident_points) <= self.max_points_per_region or self.depth >= self.max_depth):
            return

        #we subdivide and insert the points into the children
        top_left_points = []
        top_right_points = []
        bottom_left_points = []
        bottom_right_points = []
        for incident_point in self.incident_points:
            
            region_code = self.find_region(incident_point)
            match region_code:
                case "tl":
                    top_left_points.append(incident_point)
                case "tr":
                    top_right_points.append(incident_point)
                case "bl":
                    bottom_left_points.append(incident_point)
                case "br":
                    bottom_right_points.append(incident_point)

        
        if any((top_left_points, top_right_points, bottom_left_points, bottom_right_points)):
            self.has_children = True

        #now we can insert the lists of points we made into new quadtrees. they can be empty too
        new_depth = self.depth + 1
        self.top_left = Quadtree(top_left_points, {"min_lat": self.mid_lat, "max_lat": self.max_lat, "min_long": self.min_long, "max_long": self.mid_long}, new_depth)
        self.top_right = Quadtree(top_right_points, {"min_lat": self.mid_lat, "max_lat": self.max_lat, "min_long": self.mid_long, "max_long": self.max_long}, new_depth)
        self.bottom_left = Quadtree(bottom_left_points, {"min_lat": self.min_lat, "max_lat": self.mid_lat, "min_long": self.min_long, "max_long": self.mid_long}, new_depth)
        self.bottom_right = Quadtree(bottom_right_points, {"min_lat": self.min_lat, "max_lat": self.mid_lat, "min_long": self.mid_long, "max_long": self.max_long}, new_depth)

    def find_bounds(self, points):
        if not points:
            raise ValueError("Cannot find bounds for an empty list")

        latitudes = [point.latitude for point in points]
        longitudes = [point.longitude for point in points]

        return {
            "min_lat": min(latitudes),
            "max_lat": max(latitudes),
            "min_long": min(longitudes),
            "max_long": max(longitudes),
        }

    def find_region(self, incident_point):
        if incident_point.latitude <= self.mid_lat:
            #we are in the bottom half of region
            if incident_point.longitude <= self.mid_long:
                return "bl"
            else:
                return "br"
        else:
            #we are in top half of region
            if incident_point.longitude <= self.mid_long:
                return "tl"
            else:
                return "tr"

    #this recursive function searches the quadtree with a users location to find the node they are inside
    def find_node(self, incident_point):
        
        #stop searching when there are no more children to search
        if not self.has_children:
            return self
          
        #find which region the coords are actually within
        region_code = self.find_region(incident_point)

        #decode the region code and nest into the quadtree until we find the object
        match region_code:
            case "tl":
                return self.top_left.find_node(incident_point)
            case "tr":
                return self.top_right.find_node(incident_point)
            case "bl":
                return self.bottom_left.find_node(incident_point)
            case "br":
                return self.bottom_right.find_node(incident_point)

    def get_all_children(self):
        found_nodes = [self]

        # If it doesn't have children, return itself
        if not self.has_children:
            return found_nodes

        # Recursively collect all descendants
        found_nodes.extend(self.top_left.get_all_children()) #need 'extend' to flatten lists
        found_nodes.extend(self.top_right.get_all_children())
        found_nodes.extend(self.bottom_left.get_all_children())
        found_nodes.extend(self.bottom_right.get_all_children())

        return found_nodes
            

    #returns all the nodes that the incident point is near withing a geodesic (curved) distance 
    #this fn is AI generated because I am damn tired
    def find_nearby_incidents(self, incident_point, within_kms):
        # Latitude and longitude of the search centre
        lat = incident_point.latitude
        lon = incident_point.longitude
        radius_km = within_kms
        if radius_km < 0:
            raise ValueError("Search radius cannot be negative")
        
        # Build a conservative bounding rectangle.
        # Approximate 1 degree latitude as 110.574 km.
        lat_delta = radius_km / 110.574
        min_lat = lat - lat_delta
        max_lat = lat + lat_delta
        # Use the largest longitude span needed across the latitude range.
        # Near the poles, longitude degrees become very small distances.
        if min_lat <= -90 or max_lat >= 90:
            min_lon, max_lon = -180, 180
        else:
            max_abs_lat = max(abs(min_lat), abs(max_lat))
            lon_km_per_degree = (
                111.320 * math.cos(math.radians(max_abs_lat))
            )

            if lon_km_per_degree <= 0:
                min_lon, max_lon = -180, 180
            else:
                lon_delta = radius_km / lon_km_per_degree

                if lon_delta >= 180:
                    min_lon, max_lon = -180, 180
                else:
                    min_lon = lon - lon_delta
                    max_lon = lon + lon_delta
        # Collect candidate points from intersecting quadtree cells.
        candidates = []
        def search(node):
            # Skip nodes whose rectangles do not overlap the search box.
            if (
                node.max_lat < min_lat
                or node.min_lat > max_lat
                or node.max_long < min_lon
                or node.min_long > max_lon
            ):
                return

            # Check points stored in this node.
            candidates.extend(node.incident_points)
            # Search children recursively.
            if node.has_children:
                search(node.top_left)
                search(node.top_right)
                search(node.bottom_left)
                search(node.bottom_right)
        search(self)
        # Use geodesic distance to filter the candidates precisely.
        nearby = []
        for point in candidates:
            distance_km = geodesic(
                (lat, lon),
                (point.latitude, point.longitude)
            ).km

            if distance_km <= radius_km:
                nearby.append(point)
        return nearby

    class IncidentPoint:
        def __init__(self, latitude, longitude, id):
            self.latitude = latitude
            self.longitude = longitude
            self.id = id

