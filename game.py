import pygame
import sys
import random
import time

# Initialize Pygame
pygame.init()

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

# Create the screen
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("Squirrel Game")
clock = pygame.time.Clock()

# Game state
acorns = 3
scroll_offset = 0

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
        if not self.is_jumping:
            self.velocity_y = JUMP_STRENGTH
            self.is_jumping = True
    
    def update(self, boxes=None):
        # Apply gravity
        self.velocity_y += GRAVITY
        
        # Store previous position for collision detection
        self.prev_y = self.y
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
                    
                    print("prev_bottom", prev_bottom)
                    print("prev_top", prev_top)
                    print("box_bottom", box_bottom)
                    print("box_top", box_top)
                    print("new_y", new_y)
                    print("self.velocity_y", self.velocity_y)
                    print("self.is_jumping", self.is_jumping)
                    print("box.should_collect", box.should_collect)
                    # Check if hitting from below (jumping into box from bottom)
                    # The squirrel must be completely below the box and moving upward
                    if prev_bottom >= box_top and self.velocity_y < 0:
                        print("hitting from below")
                        # Check if squirrel's top (new_y) would reach or pass the box's bottom
                        # The top hitting the bottom means: new_y >= box_bottom
                        if new_y <= box_bottom:
                            print("squirrel's top reached or passed the box's bottom - collect it!")
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

# Calculate maximum jump height
# Using physics: v² = u² + 2as, where v=0 at max height
# 0 = JUMP_STRENGTH² + 2*GRAVITY*height
# height = -(JUMP_STRENGTH²) / (2*GRAVITY)
MAX_JUMP_HEIGHT = abs(JUMP_STRENGTH * JUMP_STRENGTH) / (2 * GRAVITY)  # ~140 pixels

# Initialize game objects
squirrel = Squirrel()
acorns_list = []
boxes = []
popup_acorns = []  # Acorns that pop up from boxes
next_box_spawn_offset = 200  # Next box will spawn at this scroll offset

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

# Main game loop
running = True
while running:
    # Handle events
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
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
        box = Box(box_x, box_y)
        boxes.append(box)
        next_box_spawn_offset = scroll_offset + random.randint(BOX_SPAWN_DISTANCE, BOX_SPAWN_DISTANCE + 400)
    
    # Update game objects
    squirrel.update(boxes)
    
    # Update acorns (only if game not over)
    if not squirrel.game_over:
        for acorn in acorns_list[:]:
            acorn.update()
            if not acorn.active:
                acorns_list.remove(acorn)
    
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
    
    # Draw acorn count
    acorn_text = font.render(f"Acorns: {acorns}", True, (0, 0, 0))
    text_rect = acorn_text.get_rect()
    text_rect.topright = (SCREEN_WIDTH - 10, 10)
    screen.blit(acorn_text, text_rect)
    
    # Update display
    pygame.display.flip()
    clock.tick(FPS)

pygame.quit()
sys.exit()

