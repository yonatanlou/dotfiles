## General guidlines
* Follow SOLID principles:
  - Single Responsibility Principle: A class or function should have one purpose only.
  - Open/Closed Principle: Classes should be open for extension but closed for modification.
  - Liskov Substitution Principle: Imagine a function that expects a Bird. You should be able to pass in a Sparrow or a Duck, and it should just work.
  - Interface Segregation Principle: Don't make a big, fat interface with a bunch of unrelated methods. Instead, split large interfaces into smaller, more specific ones so that classes only implement what they actually need.
  - Dependency Inversion Principle: A design rule that says high-level code should depend on abstractions, not concrete implementations.

•Name functions with existing domain vocabulary for consistency.
•Add comments only when neccesary
•Add documentation to a function only when necesseary (DEFAULT=False)
•Files should never be longer than 250-300 lines.