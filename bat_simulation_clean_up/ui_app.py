import atexit
import os.path as path
import pickle
import random
from functools import partial

import pandas as pd
from kivy.app import App
from kivy.clock import Clock
from kivy.core.window import Window

from settings.constants import (GAME_SIZE, RANDOM_OBSTACLES, SEED,
                                SHAPE_FILE)
from ui.game import Game, ObstacleWidget

random.seed(SEED)
random.seed(123)
MODEL_FILE = '../base_brain_153.pth'
OUTPUT_FILE = 'ui_game_result.csv'
BAT_SPEED = 5

if not RANDOM_OBSTACLES:
    with open(SHAPE_FILE, 'rb') as f:
        cells = pickle.load(f)
        size = len(cells)//2 + 1
else:
    size = GAME_SIZE//2
Window.size = (size, size)
print(size)
# Window.size = (500, 500)

class BatApp(App):

    def __init__(self, **kwargs):
        super(BatApp, self).__init__()
        self.data: pd.DataFrame = None
        self.experiment: int = None
        self.parent: Game
        self.obstacles: ObstacleWidget

    def build(self):

        self.parent = Game(model=MODEL_FILE,bat_speed=BAT_SPEED)


        self.parent.state.experiment = self.experiment
        # self.parent.serve_bat()
        self.obstacles = ObstacleWidget(100, 50)
        Clock.schedule_interval(
            partial(self.parent.update, self.obstacles), 1.0/120.0)
        self.parent.add_widget(self.obstacles)
        return self.parent

    def load_history(self, OUTPUT_FILE):
        if path.exists(OUTPUT_FILE):
            self.data = pd.read_csv(OUTPUT_FILE)
            self.experiment = self.data['experiment'].max() + 1

        else:
            columns = ['experiment', 'time', 'speed', 'gamma', 'signal1', 'signal2',
                       'signal3', 'distance_to_goal', 'action', 'orientation', 'reward']
            self.data = pd.DataFrame(columns=columns)
            self.experiment = 1

    def save_data(self):
        # print("saving brain...")
        # self.parent.state.brain.save()
        print("saving data...")
        print(OUTPUT_FILE)
        data = pd.concat([self.data, pd.DataFrame(self.parent.state.sample)])
        data.to_csv(OUTPUT_FILE, index=False)


if __name__ == '__main__':

    app = BatApp()
    app.load_history(OUTPUT_FILE)
    atexit.register(app.save_data)
    app.run()
