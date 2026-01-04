import pygame
import sys
import random
import time
import asyncio

# Constants
SCREEN_WIDTH = 800
SCREEN_HEIGHT = 600
FPS = 60
GRAVITY = 0.8
JUMP_STRENGTH = -15
SCROLL_SPEED = 3
SOIL_HEIGHT = 100

# Colors
SKY_BLUE = (135, 206, 235)
BROWN = (139, 69, 19)
DARK_BROWN = (101, 67, 33)
SQUIRREL_COLOR = (160, 82, 45)
ACORN_COLOR = (139, 90, 43)
BOX_COLOR = (200, 150, 100)
BOX_SPAWN_DISTANCE = 1200  # Distance between box spawns
TREE_SPAWN_DISTANCE = 1500  # Distance between tree spawns

# Game state
acorns = 3
scroll_offset = 0
score = 0  # Player score

class Squirrel:
    def __init__(self):
        self.width = 40
        self.height = 40
        self.x = 50
        self.y = SCREEN_HEIGHT - SOIL_HEIGHT - self.height
        self.velocity_y = 0
        self.is_jumping = False
        self.ground_y = SCREEN_HEIGHT - SOIL_HEIGHT - self.height
        self.prev_y = self.y  # Track previous position for collision detection
        self.prev_x = self.x  # Track previous x position for collision detection
        self.game_over = False  # Game over state
        self.rotated_image = None  # Rotated image for game over
        # Load squirrel image
        try:
            self.image = pygame.image.load("assets/squirrel.png")
            self.image = pygame.transform.scale(self.image, (self.width, self.height))
            # Create rotated image for game over (90 degrees)
            self.rotated_image = pygame.transform.rotate(self.image, 90)
        except pygame.error:
            # Fallback to a simple rectangle if image fails to load
            self.image = None
            self.rotated_image = None
    
    def jump(self):
        if not self.is_jumping and not self.game_over:
            self.velocity_y = JUMP_STRENGTH
            self.is_jumping = True
    
    def update(self, boxes=None):
        # Apply gravity
        self.velocity_y += GRAVITY
        
        # Store previous position for collision detection
        self.prev_y = self.y
        self.prev_x = self.x
        new_y = self.y + self.velocity_y
        
        # Check box collisions before moving
        if boxes:
            squirrel_rect = pygame.Rect(self.x, new_y, self.width, self.height)
            for box in boxes:
                if box.active and box.get_rect().colliderect(squirrel_rect):
                    box_rect = box.get_rect()
                    # Determine collision direction based on previous position
                    prev_bottom = self.prev_y + self.height
                    prev_top = self.prev_y
                    box_bottom = box_rect.y + box_rect.height
                    box_top = box_rect.y
                    
                    # Check if hitting from below (jumping into box from bottom)
                    # The squirrel must be completely below the box and moving upward
                    if prev_bottom >= box_top and self.velocity_y < 0:
                        # Check if squirrel's top (new_y) would reach or pass the box's bottom
                        # The top hitting the bottom means: new_y >= box_bottom
                        if new_y <= box_bottom:
                            # Squirrel's top reached or passed the box's bottom - collect it!
                            box.should_collect = True
                            # Position squirrel so its top is exactly at the box's bottom
                            new_y = box_bottom
                            self.velocity_y = 0
                        else:
                            # Squirrel is jumping up but top hasn't reached bottom yet
                            # Don't stop it - let it continue moving up until top reaches bottom
                            # We'll detect the collision again next frame
                            pass
                    # Check if landing on top of box
                    elif prev_top <= box_rect.y and self.velocity_y > 0:
                        # Squirrel is above or falling onto the box - land on top
                        # Position squirrel so its bottom is at the box's top
                        new_y = box_rect.y - self.height
                        self.velocity_y = 0
                        self.is_jumping = False
                    else:
                        self.game_over = True
        
        self.y = new_y
        
        # Check if squirrel is standing on a box (after position update)
        standing_on_box = False
        if boxes:
            squirrel_bottom = self.y + self.height
            squirrel_rect = pygame.Rect(self.x, self.y, self.width, self.height)
            for box in boxes:
                if box.active:
                    box_rect = box.get_rect()
                    box_bottom = box_rect.y + box_rect.height
                    # Check if squirrel's bottom is on top of the box
                    # Allow small tolerance for floating point precision
                    if (abs(squirrel_bottom - box_bottom) < 5 and  # Within 5 pixels of box top
                        self.x < box_rect.x + box_rect.width and
                        self.x + self.width > box_rect.x):  # Horizontally overlapping with box
                        standing_on_box = True
                        # Keep squirrel exactly on top of box
                        self.y = box_bottom - self.height
                        self.velocity_y = 0
                        self.is_jumping = False
                        break
        
        # Only apply ground collision if not standing on a box
        if not standing_on_box:
            if self.y >= self.ground_y:
                self.y = self.ground_y
                self.velocity_y = 0
                self.is_jumping = False
    
    def draw(self, surface):
        if self.game_over and self.rotated_image:
            # Draw rotated squirrel image (90 degrees) when game over
            surface.blit(self.rotated_image, (self.x, self.y))
        elif self.image:
            # Draw squirrel image
            surface.blit(self.image, (self.x, self.y))
        else:
            # Fallback: Draw squirrel body (simple rectangle if image fails to load)
            pygame.draw.rect(surface, SQUIRREL_COLOR, (self.x, self.y, self.width, self.height))
            # Draw simple face
            pygame.draw.circle(surface, (0, 0, 0), (self.x + 10, self.y + 10), 3)  # Left eye
            pygame.draw.circle(surface, (0, 0, 0), (self.x + 30, self.y + 10), 3)  # Right eye

class Acorn:
    def __init__(self, start_x, start_y):
        self.x = start_x
        self.y = start_y
        self.width = 15
        self.height = 20
        self.velocity_x = 10
        self.active = True
    
    def update(self):
        self.x += self.velocity_x
        # Deactivate if off screen
        if self.x > SCREEN_WIDTH:
            self.active = False
    
    def draw(self, surface):
        if self.active:
            # Draw acorn (simple oval)
            pygame.draw.ellipse(surface, ACORN_COLOR, (self.x, self.y, self.width, self.height))
            # Draw cap
            pygame.draw.arc(surface, DARK_BROWN, (self.x - 2, self.y, self.width + 4, self.height // 2), 0, 3.14, 3)

class PopupAcorn:
    """Animated acorn that pops up above a box"""
    def __init__(self, box_x, box_y, box_width, offset_x=0):
        self.start_time = time.time()
        self.duration = 3.0  # 3 seconds
        self.width = 15
        self.height = 20
        self.box_x = box_x  # Store box position to track it
        self.box_y = box_y
        self.box_width = box_width
        self.offset_x = offset_x  # Horizontal offset for spreading multiple acorns
        self.x = 0
        self.y = 0
        self.active = True
        self.initial_popup_distance = 40  # How far up it pops
    
    def update(self, scroll_speed):
        # Track the box position (box moves with scroll)
        self.box_x -= scroll_speed
        # Calculate x position relative to box center
        self.x = self.box_x + self.box_width // 2 - self.width // 2 + self.offset_x
        
        # Calculate animation progress (0 to 1)
        elapsed = time.time() - self.start_time
        if elapsed >= self.duration:
            self.active = False
            return
        
        progress = elapsed / self.duration
        
        # Animated pop-up: starts fast, slows down, then fades
        base_y = self.box_y - 20  # Position just above box
        if progress < 0.3:
            # Pop up quickly
            popup_progress = progress / 0.3
            self.y = base_y - (self.initial_popup_distance * popup_progress)
        elif progress < 0.7:
            # Stay at top
            self.y = base_y - self.initial_popup_distance
        else:
            # Fade down
            fade_progress = (progress - 0.7) / 0.3
            self.y = base_y - (self.initial_popup_distance * (1 - fade_progress))
    
    def draw(self, surface):
        if self.active:
            # Draw acorn (simple oval)
            pygame.draw.ellipse(surface, ACORN_COLOR, (self.x, self.y, self.width, self.height))
            # Draw cap
            pygame.draw.arc(surface, DARK_BROWN, (self.x - 2, self.y, self.width + 4, self.height // 2), 0, 3.14, 3)

class Box:
    def __init__(self, x, y):
        self.width = 40
        self.height = 40
        self.x = x
        self.y = y
        self.active = True
        self.collected = False  # Track if box has been collected
        self.should_collect = False  # Flag to mark for collection
    
    def update(self, scroll_speed):
        # Boxes scroll with the background
        self.x -= scroll_speed
        # Deactivate if off screen to the left
        if self.x + self.width < 0:
            self.active = False
    
    def draw(self, surface):
        if self.active:
            # Draw box
            color = BOX_COLOR if not self.collected else (150, 150, 150)  # Gray if collected
            pygame.draw.rect(surface, color, (self.x, self.y, self.width, self.height))
            # Draw border
            pygame.draw.rect(surface, DARK_BROWN, (self.x, self.y, self.width, self.height), 2)
            # Draw simple "?" mark to indicate it's collectible (or "✓" if collected)
            font = pygame.font.Font(None, 24)
            text_char = "✓" if self.collected else "?"
            text = font.render(text_char, True, (0, 0, 0))
            text_rect = text.get_rect(center=(self.x + self.width // 2, self.y + self.height // 2))
            surface.blit(text, text_rect)
    
    def get_rect(self):
        return pygame.Rect(self.x, self.y, self.width, self.height)

class Tree:
    def __init__(self, x, y):
        self.x = x
        self.prev_x = x
        self.y = y
        self.active = True
        # Load tree image
        try:
            self.image = pygame.image.load("assets/tree2.png")
            # Scale tree to reasonable size (adjust as needed)
            tree_height = 75  # Height of tree on screen
            tree_width = int(self.image.get_width() * (tree_height / self.image.get_height()))
            self.image = pygame.transform.scale(self.image, (tree_width, tree_height))
            self.width = tree_width
            self.height = tree_height
        except pygame.error:
            # Fallback if image fails to load
            self.image = None
            self.width = 30
            self.height = 75
    
    def update(self, scroll_speed):
        # Trees scroll with the background
        self.prev_x = self.x
        self.x -= scroll_speed
        # Deactivate if off screen to the left
        if self.x + self.width < 0:
            self.active = False
    
    def draw(self, surface):
        if self.active:
            if self.image:
                surface.blit(self.image, (self.x, self.y))
            else:
                # Fallback: draw simple rectangle
                pygame.draw.rect(surface, (34, 139, 34), (self.x, self.y, self.width, self.height))
    
    def get_rect(self):
        return pygame.Rect(self.x, self.y, self.width, self.height)

class Skunk:
    def __init__(self, x, y):
        self.x = x
        self.prev_x = x
        self.y = y
        self.active = True
        self.defeated = False  # Track if skunk is defeated
        self.image_change_time = time.time()
        self.image_change_interval = 1.5  # Change image every 1.5 seconds
        self.current_image_index = 0
        self.images = []
        self.width = 80
        self.height = 80
        self.animation_start_time = None
        self.animation_jump_height = 20
        self.animation_velocity_x = -2.5  # Horizontal velocity when falling
        self.animation_velocity_y = 0  # Vertical velocity for falling
        self.initial_y = y  # Store initial floor position
        self.defeated_floor_y = None  # Floor position when defeated
        
        # Load all skunk images
        for i in range(1, 4):
            try:
                img = pygame.image.load(f"assets/skunk_{i}.png")
                img = pygame.transform.scale(img, (self.width, self.height))
                self.images.append(img)
            except pygame.error:
                # Fallback if image fails to load
                self.images.append(None)
        
        if not self.images:
            self.images = [None] * 3
    
    def update(self, scroll_speed):
        self.prev_x = self.x
        
        if self.defeated:
            # Animate defeated skunk: jump up then fall with gravity
            if self.animation_start_time is None:
                self.animation_start_time = time.time()
                # Store the floor position when defeated
                self.defeated_floor_y = SCREEN_HEIGHT - SOIL_HEIGHT - self.height
                # Calculate initial jump velocity to reach jump height
                # Using physics: v² = u² + 2as, where v=0 at max height
                # 0 = u² + 2*(-GRAVITY)*height
                # u = sqrt(2 * GRAVITY * height)
                jump_velocity = (2 * GRAVITY * self.animation_jump_height) ** 0.5
                self.animation_velocity_y = -jump_velocity  # Negative because y increases downward
            
            # Apply gravity to vertical velocity (always, during jump and fall)
            self.animation_velocity_y += GRAVITY
            
            # Update position with velocity
            self.y += self.animation_velocity_y
            self.x += self.animation_velocity_x
            
            # Don't stop at floor - continue falling off screen
        else:
            # Normal scrolling
            self.x -= scroll_speed
            
            # Change image randomly every 2 seconds
            if time.time() - self.image_change_time >= self.image_change_interval:
                self.current_image_index = random.randint(0, len(self.images) - 1)
                self.image_change_time = time.time()
        
        # Deactivate if off screen to the left
        if self.x + self.width < 0:
            self.active = False
    
    def draw(self, surface):
        if self.active:
            if self.images and self.images[self.current_image_index]:
                surface.blit(self.images[self.current_image_index], (self.x, self.y))
            else:
                # Fallback: draw simple rectangle
                color = (100, 100, 100) if self.defeated else (50, 50, 50)
                pygame.draw.rect(surface, color, (self.x, self.y, self.width, self.height))
    
    def get_rect(self):
        return pygame.Rect(self.x, self.y, self.width, self.height)

class Bird:
    def __init__(self, x, y):
        self.x = x
        self.prev_x = x
        self.y = y
        self.active = True
        self.defeated = False  # Track if bird is defeated
        self.image_change_time = time.time()
        self.image_change_interval = 0.5  # Change image every 0.5 seconds
        self.current_image_index = 0
        self.images = []
        self.width = 60
        self.height = 60
        self.forward_speed = -0.5  # Move forward slowly
        self.animation_start_time = None
        self.animation_jump_height = 20
        self.animation_velocity_x = -2.5  # Horizontal velocity when falling
        self.animation_velocity_y = 0  # Vertical velocity for falling
        self.defeated_floor_y = None  # Floor position when defeated
        
        # Load bird images
        try:
            img1 = pygame.image.load("assets/bird_1.png")
            img1 = pygame.transform.scale(img1, (self.width, self.height))
            self.images.append(img1)
        except pygame.error:
            self.images.append(None)
        
        try:
            img2 = pygame.image.load("assets/bird_2.png")
            img2 = pygame.transform.scale(img2, (self.width, self.height))
            self.images.append(img2)
        except pygame.error:
            self.images.append(None)
        
        if not self.images:
            self.images = [None, None]
    
    def update(self, scroll_speed):
        if self.defeated:
            # Animate defeated bird: jump up then fall with gravity
            if self.animation_start_time is None:
                self.animation_start_time = time.time()
                # Store the position when defeated
                self.defeated_floor_y = self.y
                # Calculate initial jump velocity to reach jump height
                # Using physics: v² = u² + 2as, where v=0 at max height
                # 0 = u² + 2*(-GRAVITY)*height
                # u = sqrt(2 * GRAVITY * height)
                jump_velocity = (2 * GRAVITY * self.animation_jump_height) ** 0.5
                self.animation_velocity_y = -jump_velocity  # Negative because y increases downward
            
            # Apply gravity to vertical velocity (always, during jump and fall)
            self.animation_velocity_y += GRAVITY
            
            # Update position with velocity
            self.y += self.animation_velocity_y
            self.x += self.animation_velocity_x
            
            # Deactivate if off screen
            if self.x + self.width < 0 or self.y > SCREEN_HEIGHT:
                self.active = False
        else:
            self.prev_x = self.x
            # Birds scroll with the background but also move forward slowly
            self.x -= scroll_speed
            self.x += self.forward_speed  # Move forward (to the right) slowly
            
            # Change image every 0.5 seconds (alternate between the two)
            if time.time() - self.image_change_time >= self.image_change_interval:
                self.current_image_index = (self.current_image_index + 1) % len(self.images)
                self.image_change_time = time.time()
            
            # Deactivate if off screen to the left
            if self.x + self.width < 0:
                self.active = False
    
    def draw(self, surface):
        if self.active:
            if self.images and self.images[self.current_image_index]:
                surface.blit(self.images[self.current_image_index], (self.x, self.y))
            else:
                # Fallback: draw simple rectangle
                color = (100, 100, 100) if self.defeated else (100, 150, 200)
                pygame.draw.rect(surface, color, (self.x, self.y, self.width, self.height))
    
    def get_rect(self):
        return pygame.Rect(self.x, self.y, self.width, self.height)

# Calculate maximum jump height
# Using physics: v² = u² + 2as, where v=0 at max height
# 0 = JUMP_STRENGTH² + 2*GRAVITY*height
# height = -(JUMP_STRENGTH²) / (2*GRAVITY)
MAX_JUMP_HEIGHT = abs(JUMP_STRENGTH * JUMP_STRENGTH) / (2 * GRAVITY)  # ~140 pixels

# Initialize game objects
squirrel = Squirrel()
acorns_list = []
boxes = []
trees = []  # Trees on the floor
skunks = []  # Skunks on the floor
birds = []  # Birds in the air
popup_acorns = []  # Acorns that pop up from boxes
next_box_spawn_offset = 200  # Next box will spawn at this scroll offset
next_tree_spawn_offset = 500  # Next tree will spawn at this scroll offset
next_skunk_spawn_offset = 1000  # Next skunk will spawn at this scroll offset
next_bird_spawn_offset = 800  # Next bird will spawn at this scroll offset
BIRD_SPAWN_DISTANCE = 1500  # Distance between bird spawns
SKUNK_SPAWN_DISTANCE = 2000  # Distance between skunk spawns
last_box_spawn_offset = None  # Track last box spawn scroll offset
last_tree_spawn_offset = None  # Track last tree spawn scroll offset

# Font for displaying acorn count
font = pygame.font.Font(None, 36)

# Load background images
try:
    # Load upper background (for sky area above soil)
    background_up = pygame.image.load("assets/background-up.jpg")
    up_height = SCREEN_HEIGHT - SOIL_HEIGHT
    up_width = int(background_up.get_width() * (up_height / background_up.get_height()))
    background_up = pygame.transform.scale(background_up, (up_width, up_height))
except pygame.error:
    background_up = None

try:
    # Load lower background (for ground area below SOIL_HEIGHT)
    background_down = pygame.image.load("assets/background-down.jpg")
    down_height = SOIL_HEIGHT
    down_width = int(background_down.get_width() * (down_height / background_down.get_height()))
    background_down = pygame.transform.scale(background_down, (down_width, down_height))
except pygame.error:
    background_down = None

# Function to reset game state
def reset_game():
    global scroll_offset, acorns, score
    global next_box_spawn_offset, next_tree_spawn_offset, next_skunk_spawn_offset, next_bird_spawn_offset
    global last_box_spawn_offset, last_tree_spawn_offset
    global acorns_list, boxes, trees, skunks, birds, popup_acorns
    
    # Reset game state
    scroll_offset = 0
    acorns = 3
    score = 0
    next_box_spawn_offset = 200
    next_tree_spawn_offset = 500
    next_skunk_spawn_offset = 1000
    next_bird_spawn_offset = 800
    last_box_spawn_offset = None
    last_tree_spawn_offset = None
    
    # Clear all game objects
    acorns_list = []
    boxes = []
    trees = []
    skunks = []
    birds = []
    popup_acorns = []
    
    # Reset squirrel
    squirrel.game_over = False
    squirrel.x = 50
    squirrel.y = SCREEN_HEIGHT - SOIL_HEIGHT - squirrel.height
    squirrel.velocity_y = 0
    squirrel.is_jumping = False
    
    # Re-seed random for new game
    random.seed(time.time())

# Main game loop
async def main():
    global running, scroll_offset, acorns, score
    global next_box_spawn_offset, next_tree_spawn_offset, next_skunk_spawn_offset, next_bird_spawn_offset
    global last_box_spawn_offset, last_tree_spawn_offset
    global game_over_time
    
    # Initialize random generator with current time for better randomness
    random.seed(time.time())

    # Initialize Pygame
    pygame.init()
    
    # Create the screen
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("Squirrel Game")
    clock = pygame.time.Clock()
    
    # Menu state
    menu_state = "main"  # "main" or "controls"
    menu_selection = 0  # 0 = restart, 1 = show controls
    game_over_time = None  # Track when game over occurred
    
    running = True
    while running:
        # Handle events
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if squirrel.game_over:
                    # Check if 3 seconds have passed since game over
                    if game_over_time is not None and time.time() - game_over_time >= 3.0:
                        # Handle menu navigation
                        if menu_state == "main":
                            if event.key == pygame.K_UP or event.key == pygame.K_DOWN:
                                menu_selection = (menu_selection + 1) % 2
                            elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                                if menu_selection == 0:
                                    # Restart game
                                    reset_game()
                                    menu_state = "main"
                                    menu_selection = 0
                                    game_over_time = None  # Reset game over time
                                elif menu_selection == 1:
                                    # Show controls
                                    menu_state = "controls"
                        elif menu_state == "controls":
                            # Return to main menu
                            if event.key == pygame.K_ESCAPE or event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                                menu_state = "main"
                else:
                    # Normal game controls
                    if event.key == pygame.K_SPACE:
                        squirrel.jump()
                    elif event.key == pygame.K_LSHIFT or event.key == pygame.K_RSHIFT:
                        if acorns > 0:
                            # Throw acorn from squirrel position
                            acorn = Acorn(squirrel.x + squirrel.width, squirrel.y + squirrel.height // 2)
                            acorns_list.append(acorn)
                            acorns -= 1
        
        # Update scroll offset (only if game not over)
        if not squirrel.game_over:
            scroll_offset += SCROLL_SPEED
        
        # Spawn new boxes randomly (only if game not over)
        if not squirrel.game_over and scroll_offset >= next_box_spawn_offset:
            # Calculate box placement constraints
            # Squirrel's ground position (top of squirrel when on ground)
            squirrel_ground_y = SCREEN_HEIGHT - SOIL_HEIGHT - squirrel.height
            box_height = 40  # Box height (from Box class)
            
            # Box bottom (box.y + box.height) must be:
            # 1. Above the squirrel's height: box.y + box.height < squirrel_ground_y
            #    Therefore: box.y < squirrel_ground_y - box.height
            # 2. Within maximum jump reach: box.y + box.height >= squirrel_ground_y - MAX_JUMP_HEIGHT
            #    Therefore: box.y >= squirrel_ground_y - MAX_JUMP_HEIGHT - box.height
            
            # Minimum box y: highest reachable point (box bottom at max jump height)
            min_box_y = squirrel_ground_y - MAX_JUMP_HEIGHT - box_height
            
            # Maximum box y: just above squirrel (box bottom just above squirrel's top)
            max_box_y = squirrel_ground_y - box_height - 1  # -1 to ensure it's above
            
            # Ensure boxes are within valid range
            if min_box_y < max_box_y:
                box_y = random.randint(int(min_box_y), int(max_box_y))
            else:
                # Fallback: place box at a safe height
                box_y = int(squirrel_ground_y - MAX_JUMP_HEIGHT / 2 - box_height)
            
            # Verify box bottom is in correct range
            box_bottom = box_y + box_height
            if box_bottom >= squirrel_ground_y:
                # Adjust to ensure box bottom is above squirrel
                box_y = squirrel_ground_y - box_height - 1
            elif box_bottom < squirrel_ground_y - MAX_JUMP_HEIGHT:
                # Adjust to ensure box is reachable
                box_y = squirrel_ground_y - MAX_JUMP_HEIGHT - box_height
            
            # Box x position is relative to scroll offset
            box_x = SCREEN_WIDTH + 50  # Spawn just off screen to the right
            
            # Check separation from last tree spawn
            box_width = 40
            min_separation_pixels = 2 * box_width
            # Convert pixel separation to scroll offset separation
            min_separation_offset = min_separation_pixels / SCROLL_SPEED
            
            if last_tree_spawn_offset is not None:
                # Check if box would spawn too close to last tree spawn
                separation = scroll_offset - last_tree_spawn_offset
                if separation < min_separation_offset:
                    # Delay box spawn to maintain separation
                    next_box_spawn_offset = last_tree_spawn_offset + min_separation_offset
                    # Skip spawning this frame
                    pass
                else:
                    # Safe to spawn
                    box = Box(box_x, box_y)
                    boxes.append(box)
                    last_box_spawn_offset = scroll_offset
                    next_box_spawn_offset = scroll_offset + random.randint(BOX_SPAWN_DISTANCE, BOX_SPAWN_DISTANCE + 400)
            else:
                # No previous tree, safe to spawn
                box = Box(box_x, box_y)
                boxes.append(box)
                last_box_spawn_offset = scroll_offset
                next_box_spawn_offset = scroll_offset + random.randint(BOX_SPAWN_DISTANCE, BOX_SPAWN_DISTANCE + 400)
        
        # Spawn new trees randomly on the floor (only if game not over)
        if not squirrel.game_over and scroll_offset >= next_tree_spawn_offset:
            # Place tree on the floor (soil)
            soil_y = SCREEN_HEIGHT - SOIL_HEIGHT
            # Tree should be placed so its bottom aligns with the top of the soil
            # We'll position it so the bottom of the tree is at soil_y
            tree_x = SCREEN_WIDTH + 50  # Spawn just off screen to the right
            
            # Create a temporary tree to get its dimensions
            temp_tree = Tree(0, 0)
            tree_width = temp_tree.width
            tree_y = soil_y - temp_tree.height  # Position tree so bottom is at soil level
            
            # Check separation from last box spawn
            min_separation_pixels = 2 * tree_width
            # Convert pixel separation to scroll offset separation
            min_separation_offset = min_separation_pixels / SCROLL_SPEED
            
            if last_box_spawn_offset is not None:
                # Check if tree would spawn too close to last box spawn
                separation = scroll_offset - last_box_spawn_offset
                if separation < min_separation_offset:
                    # Delay tree spawn to maintain separation
                    next_tree_spawn_offset = last_box_spawn_offset + min_separation_offset
                    # Skip spawning this frame
                    pass
                else:
                    # Safe to spawn
                    tree = Tree(tree_x, tree_y)
                    trees.append(tree)
                    last_tree_spawn_offset = scroll_offset
                    next_tree_spawn_offset = scroll_offset + random.randint(TREE_SPAWN_DISTANCE, TREE_SPAWN_DISTANCE + 800)
            else:
                # No previous box, safe to spawn
                tree = Tree(tree_x, tree_y)
                trees.append(tree)
                last_tree_spawn_offset = scroll_offset
                next_tree_spawn_offset = scroll_offset + random.randint(TREE_SPAWN_DISTANCE, TREE_SPAWN_DISTANCE + 800)
        
        # Spawn new skunks randomly on the floor (only if game not over)
        if not squirrel.game_over and scroll_offset >= next_skunk_spawn_offset:
            # Place skunk on the floor (soil)
            soil_y = SCREEN_HEIGHT - SOIL_HEIGHT
            skunk_x = SCREEN_WIDTH + 50  # Spawn just off screen to the right
            skunk_y = soil_y - 80  # Position skunk so bottom is at soil level (skunk height is 80)
            skunk = Skunk(skunk_x, skunk_y)
            skunks.append(skunk)
            next_skunk_spawn_offset = scroll_offset + random.randint(SKUNK_SPAWN_DISTANCE, SKUNK_SPAWN_DISTANCE + 1000)
        
        # Spawn new birds randomly in the air (only if game not over)
        if not squirrel.game_over and scroll_offset >= next_bird_spawn_offset:
            # Calculate bird placement (similar to boxes - in the air, reachable by jumping)
            squirrel_ground_y = SCREEN_HEIGHT - SOIL_HEIGHT - squirrel.height
            bird_height = 40  # Bird height
            # Bird bottom must be above squirrel and within jump reach
            min_bird_y = squirrel_ground_y - MAX_JUMP_HEIGHT - bird_height
            max_bird_y = squirrel_ground_y - bird_height - 1
            
            if min_bird_y < max_bird_y:
                bird_y = random.randint(int(min_bird_y), int(max_bird_y))
            else:
                bird_y = int(squirrel_ground_y - MAX_JUMP_HEIGHT / 2 - bird_height)
            
            bird_x = SCREEN_WIDTH + 50  # Spawn just off screen to the right
            bird = Bird(bird_x, bird_y)
            birds.append(bird)
            next_bird_spawn_offset = scroll_offset + random.randint(BIRD_SPAWN_DISTANCE, BIRD_SPAWN_DISTANCE + 600)
        
        # Update game objects
        squirrel.update(boxes)
        
        # Check if game over was just triggered (from box collision in Squirrel.update)
        if squirrel.game_over and game_over_time is None:
            game_over_time = time.time()
        
        # Update acorns (only if game not over)
        if not squirrel.game_over:
            for acorn in acorns_list[:]:
                acorn.update()
                # Check if acorn collides with a skunk or bird
                acorn_rect = pygame.Rect(acorn.x, acorn.y, acorn.width, acorn.height)
                for skunk in skunks:
                    if not skunk.defeated and skunk.active and skunk.get_rect().colliderect(acorn_rect):
                        # Acorn hit skunk - defeat the skunk
                        skunk.defeated = True
                        acorn.active = False
                        score += 1  # Increase score
                        break
                if not acorn.active:
                    acorns_list.remove(acorn)
                    continue
                for bird in birds:
                    if not bird.defeated and bird.active and bird.get_rect().colliderect(acorn_rect):
                        # Acorn hit bird - defeat the bird
                        bird.defeated = True
                        acorn.active = False
                        score += 1  # Increase score
                        break
                if not acorn.active:
                    acorns_list.remove(acorn)
        
        # Update trees (only if game not over)
        for tree in trees[:]:
            if not squirrel.game_over:
                tree.update(SCROLL_SPEED)
            if not tree.active:
                trees.remove(tree)
        
        # Update skunks
        for skunk in skunks[:]:
            skunk.update(SCROLL_SPEED if not squirrel.game_over else 0)
            if not skunk.active:
                skunks.remove(skunk)
        
        # Update birds (only if game not over)
        for bird in birds[:]:
            if not squirrel.game_over:
                bird.update(SCROLL_SPEED)
            if not bird.active:
                birds.remove(bird)
        
        # Check tree collisions with squirrel (only left side collision triggers game over)
        if not squirrel.game_over:
            squirrel_rect = pygame.Rect(squirrel.x, squirrel.y, squirrel.width, squirrel.height)
            for tree in trees:
                if tree.active and tree.get_rect().colliderect(squirrel_rect):
                    # Check if squirrel hit the left side of the tree
                    tree_rect = tree.get_rect()
                    tree_left = tree_rect.x
                    prev_tree_left = tree.prev_x
                    # If squirrel's right side hits the tree's left side, game over
                    # Check if squirrel was to the left and now is colliding from the left side
                    if prev_tree_left >= squirrel.x + squirrel.width and tree_left <= squirrel.x + squirrel.width:
                        # Game over - hit left side of tree
                        squirrel.game_over = True
                        if game_over_time is None:
                            game_over_time = time.time()
                        break
            
            # Check skunk collisions with squirrel (only left side collision triggers game over)
            for skunk in skunks:
                if not skunk.defeated and skunk.active and skunk.get_rect().colliderect(squirrel_rect):
                    # Check if squirrel hit the left side of the skunk
                    skunk_rect = skunk.get_rect()
                    skunk_left = skunk_rect.x
                    prev_skunk_left = skunk.prev_x
                    # If squirrel's right side hits the skunk's left side, game over
                    if prev_skunk_left >= squirrel.x + squirrel.width and skunk_left <= squirrel.x + squirrel.width:
                        # Game over - hit left side of skunk
                        squirrel.game_over = True
                        if game_over_time is None:
                            game_over_time = time.time()
                        break
            
            # Check bird collisions with squirrel (only left side collision triggers game over)
            for bird in birds:
                if not bird.defeated and bird.active and bird.get_rect().colliderect(squirrel_rect):
                    # Check if squirrel hit the left side of the bird
                    bird_rect = bird.get_rect()
                    bird_left = bird_rect.x
                    prev_bird_left = bird.prev_x
                    # If squirrel's right side hits the bird's left side, game over
                    if prev_bird_left >= squirrel.x + squirrel.width and bird_left <= squirrel.x + squirrel.width:
                        # Game over - hit left side of bird
                        squirrel.game_over = True
                        if game_over_time is None:
                            game_over_time = time.time()
                        break
        
        # Update boxes and check collection collisions (only if game not over)
        squirrel_rect = pygame.Rect(squirrel.x, squirrel.y, squirrel.width, squirrel.height)
        for box in boxes[:]:
            if not squirrel.game_over:
                box.update(SCROLL_SPEED)
            if not box.active:
                boxes.remove(box)
            elif not box.collected:
                # Check if box was marked for collection (squirrel's top hit box's bottom)
                if box.should_collect:
                    # Squirrel collected the box by hitting with its top at the box's bottom
                    box.collected = True
                    box.should_collect = False  # Reset flag
                    acorns_gained = random.randint(1, 3)
                    acorns += acorns_gained
                    # Create popup acorns above the box
                    for i in range(acorns_gained):
                        # Spread them out horizontally
                        offset_x = (i - (acorns_gained - 1) / 2) * 25
                        popup = PopupAcorn(box.x, box.y, box.width, offset_x)
                        popup_acorns.append(popup)
                elif box.get_rect().colliderect(squirrel_rect):
                    # Reset collection flag if not hitting from below
                    box.should_collect = False
        
        # Update popup acorns (only if game not over)
        for popup in popup_acorns[:]:
            if not squirrel.game_over:
                popup.update(SCROLL_SPEED)
            if not popup.active:
                popup_acorns.remove(popup)
    
    # Draw everything
    # Draw scrolling upper background (sky area above soil)
        # Scrolling stops automatically when game_over because scroll_offset stops updating
        if background_up:
            up_offset = scroll_offset % background_up.get_width()
            for i in range(-1, 3):
                bg_x = (i * background_up.get_width()) - up_offset
                screen.blit(background_up, (bg_x, 0))
        else:
            # Fallback to solid color if image fails to load
            pygame.draw.rect(screen, SKY_BLUE, (0, 0, SCREEN_WIDTH, SCREEN_HEIGHT - SOIL_HEIGHT))
    
        # Draw scrolling lower background (ground area below SOIL_HEIGHT)
        # Scrolling stops automatically when game_over because scroll_offset stops updating
        soil_y = SCREEN_HEIGHT - SOIL_HEIGHT
        if background_down:
            down_offset = scroll_offset % background_down.get_width()
            for i in range(-1, 3):
                bg_x = (i * background_down.get_width()) - down_offset
                screen.blit(background_down, (bg_x, soil_y))
        else:
            # Fallback: Draw scrolling soil (ground) if image fails to load
            for i in range(-1, 3):
                soil_x = (i * SCREEN_WIDTH) - (scroll_offset % SCREEN_WIDTH)
                pygame.draw.rect(screen, BROWN, (soil_x, soil_y, SCREEN_WIDTH, SOIL_HEIGHT))
                # Add some texture
                for j in range(0, SCREEN_WIDTH, 20):
                    pygame.draw.line(screen, DARK_BROWN, 
                                   (soil_x + j, soil_y), 
                                   (soil_x + j, SCREEN_HEIGHT), 1)
    
        # Draw trees (on the floor)
        for tree in trees:
            tree.draw(screen)
        
        # Draw skunks (on the floor)
        for skunk in skunks:
            skunk.draw(screen)
        
        # Draw birds (in the air)
        for bird in birds:
            bird.draw(screen)
        
        # Draw boxes
        for box in boxes:
            box.draw(screen)
        
        # Draw popup acorns (above boxes)
        for popup in popup_acorns:
            popup.draw(screen)
        
        # Draw squirrel
        squirrel.draw(screen)
        
        # Draw acorns (thrown acorns)
        for acorn in acorns_list:
            acorn.draw(screen)
    
    # Draw score (top left)
        score_text = font.render(f"Points: {score}", True, (0, 0, 0))
        score_rect = score_text.get_rect()
        score_rect.topleft = (10, 10)
        screen.blit(score_text, score_rect)
    
    # Draw acorn count (top right)
        acorn_text = font.render(f"Acorns: {acorns}", True, (0, 0, 0))
        text_rect = acorn_text.get_rect()
        text_rect.topright = (SCREEN_WIDTH - 10, 10)
        screen.blit(acorn_text, text_rect)
    
        # Draw game over menu (only after 3 second delay)
        if squirrel.game_over:
            # Check if 3 seconds have passed since game over
            show_menu = game_over_time is not None and time.time() - game_over_time >= 3.0
            
            # Semi-transparent overlay
            overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT))
            overlay.set_alpha(200)
            overlay.fill((0, 0, 0))
            screen.blit(overlay, (0, 0))
            
            menu_font = pygame.font.Font(None, 72)
            menu_item_font = pygame.font.Font(None, 48)
            instruction_font = pygame.font.Font(None, 32)
            
            if not show_menu:
                # Show "GAME OVER" text while waiting
                game_over_text = menu_font.render("GAME OVER", True, (255, 0, 0))
                game_over_rect = game_over_text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2))
                screen.blit(game_over_text, game_over_rect)
            elif menu_state == "main":
                # Game Over title
                game_over_text = menu_font.render("GAME OVER", True, (255, 0, 0))
                game_over_rect = game_over_text.get_rect(center=(SCREEN_WIDTH // 2, 150))
                screen.blit(game_over_text, game_over_rect)
                
                # Final score
                final_score_text = font.render(f"Final Score: {score}", True, (255, 255, 255))
                final_score_rect = final_score_text.get_rect(center=(SCREEN_WIDTH // 2, 220))
                screen.blit(final_score_text, final_score_rect)
                
                # Menu options
                menu_y = 300
                menu_items = ["Restart", "Show Controls"]
                
                for i, item in enumerate(menu_items):
                    color = (255, 255, 0) if i == menu_selection else (255, 255, 255)
                    item_text = menu_item_font.render(item, True, color)
                    item_rect = item_text.get_rect(center=(SCREEN_WIDTH // 2, menu_y + i * 60))
                    screen.blit(item_text, item_rect)
                    
                    # Draw selection indicator (moved further left to avoid overlap)
                    if i == menu_selection:
                        indicator = ">"
                        indicator_text = menu_item_font.render(indicator, True, (255, 255, 0))
                        indicator_rect = indicator_text.get_rect(center=(SCREEN_WIDTH // 2 - 180, menu_y + i * 60))
                        screen.blit(indicator_text, indicator_rect)
                
                # Instructions
                help_text = instruction_font.render("Use UP/DOWN to navigate, ENTER/SPACE to select", True, (200, 200, 200))
                help_rect = help_text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT - 50))
                screen.blit(help_text, help_rect)
            
            elif menu_state == "controls":
                # Controls title
                controls_title = menu_font.render("Controls", True, (255, 255, 255))
                controls_title_rect = controls_title.get_rect(center=(SCREEN_WIDTH // 2, 100))
                screen.blit(controls_title, controls_title_rect)
                
                # Control instructions
                controls = [
                    "SPACE - Jump",
                    "SHIFT - Throw Acorn",
                    "",
                    "Collect boxes for acorns!",
                    "Avoid trees, skunks, and birds!",
                    "Hit enemies with acorns to score!",
                ]
                
                controls_y = 200
                for control in controls:
                    if control:
                        control_text = instruction_font.render(control, True, (255, 255, 255))
                        control_rect = control_text.get_rect(center=(SCREEN_WIDTH // 2, controls_y))
                        screen.blit(control_text, control_rect)
                    controls_y += 40
                
                # Return instruction
                return_text = instruction_font.render("Press ESC, ENTER, or SPACE to return", True, (200, 200, 200))
                return_rect = return_text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT - 50))
                screen.blit(return_text, return_rect)
    
        # Update display
        pygame.display.flip()
        clock.tick(FPS)
        await asyncio.sleep(0)  # Yield control for pygbag

    pygame.quit()
    sys.exit()

# Run the game
if __name__ == "__main__":
        import asyncio
        asyncio.run(main())

