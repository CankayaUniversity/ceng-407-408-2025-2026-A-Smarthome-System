export const ROOM_IDS = ['living', 'kitchen', 'bedroom', 'entrance', 'bathroom', 'garden'];

export const ROOM_LABELS = {
    living: 'Living Room',
    kitchen: 'Kitchen',
    bedroom: 'Bedroom',
    entrance: 'Entrance',
    bathroom: 'Bathroom',
    garden: 'Garden',
};

export const DASHBOARD_ROOM_TABS = [
    { id: 'all', label: 'All' },
    { id: 'living', label: 'Living' },
    { id: 'kitchen', label: 'Kitchen' },
    { id: 'bedroom', label: 'Bedroom' },
    { id: 'entrance', label: 'Entrance' },
    { id: 'bathroom', label: 'Bathroom' },
    { id: 'garden', label: 'Garden' },
];

function deviceToRoom(deviceName) {
    const n = (deviceName || '').toLowerCase();
    if (n.includes('kitchen')) return 'kitchen';
    if (n.includes('bedroom')) return 'bedroom';
    if (n.includes('door') || n.includes('front') || n.includes('entrance')) return 'entrance';
    if (n.includes('bath')) return 'bathroom';
    if (n.includes('garden')) return 'garden';
    if (n.includes('living') || n.includes('main') || n.includes('rpi')) return 'living';
    return 'living';
}

export function resolveRoom(device) {
    if (!device) return 'living';
    if (device.room && ROOM_IDS.includes(device.room)) return device.room;
    return deviceToRoom(device.name);
}

export function matchesRoomTab(roomId, tabId) {
    if (tabId === 'all') return true;
    return roomId === tabId;
}
