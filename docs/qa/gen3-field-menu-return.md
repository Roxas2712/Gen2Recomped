# Party field-action return

Ordinary Sapphire play taught Flash through HM05 and used it from the party
menu. The presentation and cave lighting completed, but closing the party
screen called its cancellation callback, recreating START underneath the
field animation and text. Another B press was required to walk again.

Separate a successful field-action close from cancellation. Flash and the
other immediately admitted field actions return directly to the map.
Object-script Cut/Rock Smash and Secret Power use the same successful
close. Refused actions keep the party open, and ordinary cancellation still
returns to START. Fly retains its existing destination-picker return path.

The five-edition CPU regression opens the real START and party screens,
runs the real Flash action and text completion, and verifies the resulting
stack. It also checks cancellation, refusal and duplicate late callbacks.
The presentation callback is controlled in that fixture; native visual
acceptance remains separate. No ROMs, saves or generated art are included.
