//
//  MGTemplateEngineTests.m
//  MGTemplateEngine
//
//  Created by Robert Bowdidge on 4/26/2016.
//

#import <XCTest/XCTest.h>

#import "MGTemplateEngine.h"
#import "ICUTemplateMatcher.h"

@interface TemplateEngineTestDelegate : NSObject<MGTemplateEngineDelegate>
@property (weak, atomic) NSString *lastError;

- (void)templateEngine:(MGTemplateEngine *)engine encounteredError:(NSError *)error isContinuing:(BOOL)continuing;
@end


@interface MGTemplateEngineTest : XCTestCase {
    MGTemplateEngine *engine_;
    TemplateEngineTestDelegate *delegate_;
}

@end

@implementation TemplateEngineTestDelegate

- (void)templateEngine:(MGTemplateEngine *)engine encounteredError:(NSError *)error isContinuing:(BOOL)continuing {
    self.lastError = [error localizedDescription];
}
- (void) clearLastError {
    self.lastError = nil;
}

@end

@implementation MGTemplateEngineTest
- (void)setUp {
    engine_ = [[MGTemplateEngine alloc] init];
    // Why is this required?
    [engine_ setMatcher: [ICUTemplateMatcher matcherWithTemplateEngine: engine_]];
    delegate_ = [[TemplateEngineTestDelegate alloc] init];
    [engine_ setDelegate: delegate_];
}

- (void) tearDown {
}

- (void) testSimpleTemplate {
    NSString *result = [engine_ processTemplate: @"foo" withVariables: [NSDictionary dictionaryWithObject: @"1" forKey: @"foo"]];
    XCTAssertEqualObjects(@"foo", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testSimpleIfTemplate {
    NSString *result = [engine_ processTemplate: @"{% if foo == 1 %}bah{%/if%}" withVariables: [NSDictionary dictionaryWithObject: @"1" forKey: @"foo"]];
    XCTAssertEqualObjects(@"bah", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testErrorIfTemplate {
    NSString *result = [engine_ processTemplate: @"{% if foo == 1 %}bah" withVariables: [NSDictionary dictionaryWithObject: @"1" forKey: @"foo"]];
    XCTAssertEqualObjects(@"Finished processing template, but 1 block was left open (if).", [delegate_ lastError], @"");
    XCTAssertEqualObjects(@"bah", result, @"");
}

- (void) testInvalidVariable {
    NSString *result = [engine_ processTemplate: @"{{ hello }}" withVariables: [NSDictionary dictionary]];
    XCTAssertEqualObjects(@"", result, @"");
    // XCTAssertEqualObjects(@"\"hello\" is not a valid variable", [delegate_ lastError], @"");
}

- (void) testInvalidMarker {
    NSString *result = [engine_ processTemplate: @"{%hello%}" withVariables: [NSDictionary dictionary]];
    XCTAssertEqualObjects(@"", result, @"");
    XCTAssertEqualObjects(@"\"hello\" is not a valid marker", [delegate_ lastError], @"");
}

- (void) testSimpleVariable {
    NSString *result = [engine_ processTemplate: @"{{ var }}" withVariables: [NSDictionary dictionaryWithObject: @"hello" forKey: @"var"]];
    XCTAssertEqualObjects(@"hello", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testSimpleVariableNoSpaces {
    NSString *result = [engine_ processTemplate: @"{{var}}" withVariables: [NSDictionary dictionaryWithObject: @"hello" forKey: @"var"]];
    XCTAssertEqualObjects(@"hello", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testUppercaseFilter {
    NSString *result = [engine_ processTemplate: @"{{var|uppercase}}" withVariables: [NSDictionary dictionaryWithObject: @"hello" forKey: @"var"]];
    XCTAssertEqualObjects(@"HELLO", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testConstants {
    NSString *result = [engine_ processTemplate: @"We also know about {{ YES }} and {{ NO }} or {{ true }} and {{ false }}"
                                  withVariables: [NSDictionary dictionary]];
    XCTAssertEqualObjects(@"We also know about 1 and 0 or 1 and 0", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testMath {
    NSString *result = [engine_ processTemplate: @"Is 1 less than 2? {% if 1 < 2 %} Yes! {% else %} No? {% /if %}"
                                  withVariables: [NSDictionary dictionary]];
    XCTAssertEqualObjects(@"Is 1 less than 2?  Yes! ", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

// TODO(bowdidge): This fails - comparisons only work on numbers.
- (void) disableTestCompareMatchingStrings {
    NSString *result = [engine_ processTemplate: @"Is x equalsstring y? {% if x equalsstring y %} Yes! {% else %} No! {% /if %}"
                                  withVariables: [NSDictionary dictionaryWithObjectsAndKeys: @"x", @"x", @"y", @"y", nil]];
    XCTAssertEqualObjects(@"Is x equalsstring y?  Yes! ", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testCompareDifferentStrings {
    NSString *result = 	result = [engine_ processTemplate: @"Is x1 equalsstring x2? {% if x1 equalsstring x2 %} Yes! {% else %} No? {% /if %}"
                                            withVariables: [NSDictionary dictionaryWithObjectsAndKeys: @"x", @"x1", @"x", @"x2", nil]];
    XCTAssertEqualObjects(@"Is x1 equalsstring x2?  Yes! ", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testLiteral {
    NSString *result = [engine_ processTemplate: @"{% literal %}This text won't be {% now %} interpreted.{% /literal %}"
                                  withVariables: [NSDictionary dictionary]];
    XCTAssertEqualObjects(@"This text won't be {% now %} interpreted.", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testSimpleCountTemplate {
    NSString *result = [engine_ processTemplate: @"{{foo.@count}}" withVariables: [NSDictionary dictionaryWithObject: [NSArray arrayWithObject: @"1"] forKey: @"foo"]];
    XCTAssertEqualObjects(@"1", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testSimpleCountZeroTemplate {
    NSString *result = [engine_ processTemplate: @"{{foo.@count}}" withVariables: [NSDictionary dictionaryWithObject: [NSArray array] forKey: @"foo"]];
    XCTAssertEqualObjects(@"0", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testArrayCount {
    NSNumber *count = [[NSArray array] valueForKeyPath: @"@count"];
    XCTAssertEqual(0, [count intValue], @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testSimpleIfCountZeroTemplate {
    NSString *result = [engine_ processTemplate: @"{% if foo.@count != 0 %}not-zero{% else %}zero{%/if%}" withVariables: [NSDictionary dictionaryWithObject: [NSArray array] forKey: @"foo"]];
    XCTAssertEqualObjects(@"zero", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testSimpleIfCountZeroDictTemplate {
    NSDictionary *dict = [NSDictionary dictionaryWithObject: [NSDictionary dictionaryWithObject: [NSArray array] forKey: @"myArray"] forKey: @"myKey"];
    NSString *result = [engine_ processTemplate: @"{% if myKey.myArray.@count != 0 %}not-zero{% else %}zero{%/if%}" withVariables: dict];
    XCTAssertEqualObjects(@"zero", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testNestedIf {
    NSString *result = [engine_ processTemplate: @"{% if false %}level1{% if false}level2{% /if %}level1{% /if %}level0"
                                  withVariables: [NSDictionary dictionaryWithObject: [NSArray array] forKey: @"foo"]];
    XCTAssertEqualObjects(@"level0", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

- (void) testSimpleIfCountNonZeroDictTemplate {
    NSDictionary *dict = [NSDictionary dictionaryWithObject: [NSDictionary dictionaryWithObject: [NSArray arrayWithObject: @"a"] forKey: @"myArray"] forKey: @"myKey"];
    NSString *result = [engine_ processTemplate: @"{% if myKey.myArray.@count != 0 %}not-zero{% else %}zero{%/if%}" withVariables: dict];
    XCTAssertEqualObjects(@"not-zero", result, @"");
    XCTAssertNil([delegate_ lastError], @"");
}

// TODO: Add support for section.
- (void) testSection {
    // Not documented, but let's add tests anyway.
    NSString *result = [engine_ processTemplate: @"{%section%}Hello, World{%/section%}"
                                  withVariables: [NSDictionary dictionary]];
    XCTAssertEqualObjects(@"Hello, World", result, @"");
    XCTAssertEqualObjects(@"Marker \"/section\" reported that a non-existent block ended", [delegate_ lastError], @"");
}

// TODO: Add support for section.
- (void) testSectionAndIf {
    // Not documented, but let's add tests anyway.
    NSString *result = [engine_ processTemplate: @"{%if false%}{%section%}Hello, World{%/section%}{%/if%}"
                                  withVariables: [NSDictionary dictionary]];
    XCTAssertEqualObjects(@"", result, @"");
    XCTAssertEqualObjects(@"Marker \"/section\" reported that a block ended, but current block was started by \"if\" marker", [delegate_ lastError], @"");
}
@end

