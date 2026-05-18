class DashboardRoomTab {
  final String id;
  final String label;

  const DashboardRoomTab(this.id, this.label);
}

const roomIds = <String>[
  'living',
  'kitchen',
  'bedroom',
  'entrance',
  'bathroom',
  'garden',
];

const roomLabels = <String, String>{
  'living': 'Living Room',
  'kitchen': 'Kitchen',
  'bedroom': 'Bedroom',
  'entrance': 'Entrance',
  'bathroom': 'Bathroom',
  'garden': 'Garden',
};

const dashboardRoomTabs = <DashboardRoomTab>[
  DashboardRoomTab('all', 'All'),
  DashboardRoomTab('living', 'Living'),
  DashboardRoomTab('kitchen', 'Kitchen'),
  DashboardRoomTab('bedroom', 'Bedroom'),
  DashboardRoomTab('entrance', 'Entrance'),
  DashboardRoomTab('bathroom', 'Bathroom'),
  DashboardRoomTab('garden', 'Garden'),
];

String deviceToRoom(String? deviceName) {
  final n = (deviceName ?? '').toLowerCase();
  if (n.contains('kitchen')) return 'kitchen';
  if (n.contains('bedroom')) return 'bedroom';
  if (n.contains('door') || n.contains('front') || n.contains('entrance')) {
    return 'entrance';
  }
  if (n.contains('bath')) return 'bathroom';
  if (n.contains('garden')) return 'garden';
  if (n.contains('living') || n.contains('main') || n.contains('rpi')) {
    return 'living';
  }
  return 'living';
}

String resolveRoom(Map<String, dynamic>? device) {
  if (device == null) return 'living';
  final room = device['room']?.toString();
  if (room != null && roomIds.contains(room)) return room;
  return deviceToRoom(device['name']?.toString());
}

bool matchesRoomTab(String roomId, String tabId) {
  if (tabId == 'all') return true;
  return roomId == tabId;
}

String roomLabel(String roomId) => roomLabels[roomId] ?? 'Home';
