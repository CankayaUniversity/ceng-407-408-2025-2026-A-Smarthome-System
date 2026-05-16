import { createPortal } from 'react-dom';

const ModalOverlay = ({ onClose, children, zIndex = 2000 }) => createPortal(
    <div
        className="modal-overlay"
        style={{ zIndex }}
        onClick={onClose}
        role="presentation"
    >
        {children}
    </div>,
    document.body
);

export default ModalOverlay;
