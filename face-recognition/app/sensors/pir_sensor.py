import time
from gpiozero import MotionSensor

from app.config import (
    PIR_GPIO_PIN,
    MOTION_CONFIRMATION_CHECKS,
    MOTION_CONFIRMATION_INTERVAL,
    MOTION_CONFIRMATION_REQUIRED,
)


class PIRSensor:
    def __init__(self, pin: int = PIR_GPIO_PIN):
        self.sensor = MotionSensor(pin)

    def motion_detected(self) -> bool:
        positive_reads = 0

        for _ in range(MOTION_CONFIRMATION_CHECKS):
            if self.sensor.motion_detected:
                positive_reads += 1
            time.sleep(MOTION_CONFIRMATION_INTERVAL)

        return positive_reads >= MOTION_CONFIRMATION_REQUIRED