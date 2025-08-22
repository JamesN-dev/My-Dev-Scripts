import time

import pyautogui

pyautogui.PAUSE = 2.5
pyautogui.FAILSAFE = True


def main():
    pyautogui.moveTo(850, 500, 2)

    pyautogui.click(x=900, y=500)

    pyautogui.moveTo(850, 450, 2)


count = 0
while count < 10:
    main()
    count += 1
    print(f"Iteration {count} completed.")
    time.sleep(10)
