/// Basic annotation
class Step {
  final String pattern;
  const Step(this.pattern);
}

class Given extends Step {
  const Given(super.pattern);
}

class When extends Step {
  const When(super.pattern);
}

class Then extends Step {
  const Then(super.pattern);
}

class And extends Step {
  const And(super.pattern);
}

class But extends Step {
  const But(super.pattern);
}
