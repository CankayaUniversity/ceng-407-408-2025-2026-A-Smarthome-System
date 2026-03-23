from gpiozero import MotionSensor
from app.config import PIR_GPIO_PIN


class PIRSensor:
    def __init__(self, pin: int = PIR_GPIO_PIN):
        self.sensor = MotionSensor(pin)

    def motion_detected(self) -> bool:
        return self.sensor.motion_detected