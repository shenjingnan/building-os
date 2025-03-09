__version__ = "0.1.0"
__author__ = "shenjingnan"
__all__ = ["useful_function", "UsefulClass"]

from .module1 import useful_function
from .module2 import UsefulClass

import logging

logging.getLogger(__name__).addHandler(logging.NullHandler())

DEFAULT_TIMEOUT = 30
